# CloudFront Origin Access Identity for S3
resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  count   = var.s3_bucket_regional_domain_name != null ? 1 : 0
  comment = "OAI for S3 bucket"
}

# CloudFront Distribution with API Gateway Origin
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.ipv6_enabled
  comment             = "Squrl URL Shortener CloudFront Distribution - ${var.environment}"
  default_root_object = var.s3_bucket_name != null ? "index.html" : ""
  price_class         = var.price_class
  web_acl_id          = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
  http_version        = var.http2_enabled ? "http2" : "http1.1"

  # Primary origin - API Gateway
  origin {
    domain_name = var.api_gateway_domain_name
    origin_id   = "api-gateway-${var.environment}"
    origin_path = "/${var.api_gateway_stage_name}"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }

    # Custom headers for origin identification
    custom_header {
      name  = "X-CloudFront-Environment"
      value = var.environment
    }
  }

  # Optional S3 origin for static content
  dynamic "origin" {
    for_each = var.s3_bucket_regional_domain_name != null ? [1] : []
    content {
      domain_name = var.s3_bucket_regional_domain_name
      origin_id   = "s3-static-${var.environment}"
      
      s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.s3_oai[0].cloudfront_access_identity_path
      }
    }
  }

  # Default cache behavior - serve static content if S3 is available, otherwise API
  default_cache_behavior {
    target_origin_id         = var.s3_bucket_regional_domain_name != null ? "s3-static-${var.environment}" : "api-gateway-${var.environment}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = var.s3_bucket_regional_domain_name != null ? ["GET", "HEAD", "OPTIONS"] : ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    compress                 = true
    cache_policy_id          = var.s3_bucket_regional_domain_name != null ? aws_cloudfront_cache_policy.static_content.id : aws_cloudfront_cache_policy.api_default.id
    origin_request_policy_id = var.s3_bucket_regional_domain_name != null ? null : aws_cloudfront_origin_request_policy.api_default.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Cache behavior for /create endpoint (no caching) - Most specific first
  ordered_cache_behavior {
    path_pattern             = "/create"
    target_origin_id         = "api-gateway-${var.environment}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    compress                 = var.enable_compression
    cache_policy_id          = aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_default.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Cache behavior for /stats endpoint
  ordered_cache_behavior {
    path_pattern             = "/stats/*"
    target_origin_id         = "api-gateway-${var.environment}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    compress                 = var.enable_compression
    cache_policy_id          = aws_cloudfront_cache_policy.stats.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_default.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }


  # Cache behavior for short code redirects - catch paths that look like short codes
  # Using pattern to match short codes while avoiding conflicts with static files
  ordered_cache_behavior {
    path_pattern             = "/????????"
    target_origin_id         = "api-gateway-${var.environment}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = false # Redirects don't benefit from compression
    cache_policy_id          = aws_cloudfront_cache_policy.redirect.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.redirect.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Cache behavior for /api/* paths - catch remaining API paths
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "api-gateway-${var.environment}"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = false # Redirects don't benefit from compression
    cache_policy_id          = aws_cloudfront_cache_policy.redirect.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.redirect.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }


  # Geographic restrictions (if needed in the future)
  restrictions {
    geo_restriction {
      restriction_type = "none"
      # locations        = ["US", "CA", "GB", "DE"] # Uncomment to whitelist specific countries
    }
  }

  # Custom domain configuration (if provided)
  aliases = var.custom_domain_name != null ? [var.custom_domain_name] : []

  # SSL certificate configuration
  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == null ? true : false
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != null ? "TLSv1.2_2021" : null
  }


  # Real-time logs (optional, can be expensive)
  dynamic "logging_config" {
    for_each = var.enable_real_time_logs ? [1] : []
    content {
      bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
      include_cookies = false
      prefix          = "cloudfront-logs/"
    }
  }

  tags = merge(var.tags, {
    Name        = "squrl-cloudfront-${var.environment}"
    Environment = var.environment
  })

  # Prevent destruction in production
  lifecycle {
    prevent_destroy = false # Set to true for production
  }
}

# S3 bucket for CloudFront access logs (if enabled)
resource "aws_s3_bucket" "cloudfront_logs" {
  count  = var.enable_real_time_logs ? 1 : 0
  bucket = "squrl-cloudfront-logs-${var.environment}-${random_id.bucket_suffix[0].hex}"

  tags = merge(var.tags, {
    Name        = "squrl-cloudfront-logs-${var.environment}"
    Environment = var.environment
  })
}

resource "random_id" "bucket_suffix" {
  count       = var.enable_real_time_logs ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "cloudfront_logs" {
  count  = var.enable_real_time_logs ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count  = var.enable_real_time_logs ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    filter {
      prefix = "cloudfront-logs/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  count  = var.enable_real_time_logs ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count  = var.enable_real_time_logs ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}