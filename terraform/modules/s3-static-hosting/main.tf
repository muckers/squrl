# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
    Type        = "static-website"
  })
}

# Configure S3 bucket for static website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }

  # Optional routing rules for SPA support
  routing_rules = jsonencode([
    {
      Condition = {
        KeyPrefixEquals = "api/"
      }
      Redirect = {
        ReplaceKeyWith = "index.html"
      }
    }
  ])
}

# Enable versioning if specified
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Configure server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public ACLs and policies by default (CloudFront OAI will handle access)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  # If CloudFront OAI is provided, block all public access
  # Otherwise, allow public read access for direct website hosting
  block_public_acls       = var.cloudfront_oai_arn != null ? true : false
  block_public_policy     = var.cloudfront_oai_arn != null ? true : false
  ignore_public_acls      = var.cloudfront_oai_arn != null ? true : false
  restrict_public_buckets = var.cloudfront_oai_arn != null ? true : false
}

# Bucket policy for CloudFront OAI access or public read access
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  # Wait for public access block to be configured
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = var.cloudfront_oai_arn != null ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAIAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.cloudfront_oai_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# CORS configuration for API calls from the static website
resource "aws_s3_bucket_cors_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = var.cors_max_age_seconds
  }

  # More restrictive CORS rule for production
  dynamic "cors_rule" {
    for_each = var.environment == "prod" && length(var.cors_allowed_origins) == 1 && var.cors_allowed_origins[0] == "*" ? [1] : []
    content {
      allowed_headers = ["Authorization", "Content-Type", "Content-Length"]
      allowed_methods = ["GET", "POST"]
      allowed_origins = [
        "https://${var.bucket_name}",
        "https://*.${var.bucket_name}"
      ]
      expose_headers  = ["ETag"]
      max_age_seconds = 86400
    }
  }
}

# Optional: Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  count  = var.enable_lifecycle_management ? 1 : 0
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    # Empty filter to apply to all objects
    filter {}

    # Delete old versions after specified days
    noncurrent_version_expiration {
      noncurrent_days = var.old_version_expiration_days
    }

    # Delete incomplete multipart uploads after specified days
    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_upload_cleanup_days
    }
  }
}

# Optional: Logging configuration (only if specified)
resource "aws_s3_bucket_logging" "website" {
  count  = var.access_log_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.website.id

  target_bucket = var.access_log_bucket
  target_prefix = "access-logs/${var.bucket_name}/"
}

# Optional: Notification configuration for monitoring
resource "aws_s3_bucket_notification" "website" {
  count  = var.enable_notifications ? 1 : 0
  bucket = aws_s3_bucket.website.id

  # Example: CloudWatch Events for object creation
  eventbridge = var.enable_notifications
}