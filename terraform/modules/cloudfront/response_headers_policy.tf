# Response Headers Policy for Security Headers
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "squrl-security-headers-${var.environment}"
  comment = "Security headers policy for Squrl API"

  # CORS configuration
  cors_config {
    access_control_allow_credentials = false
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "POST", "OPTIONS", "PUT", "DELETE", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"] # Allow all origins for public API
    }

    access_control_expose_headers {
      items = [
        "Date",
        "ETag",
        "Server",
        "X-RateLimit-Limit",
        "X-RateLimit-Remaining", 
        "X-RateLimit-Reset"
      ]
    }

    access_control_max_age_sec = 86400 # 24 hours
  }

  # Security headers
  security_headers_config {
    # Content Type Options
    content_type_options {
      override = true
    }

    # Frame Options
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Referrer Policy
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Strict Transport Security
    strict_transport_security {
      access_control_max_age_sec = 31536000 # 1 year
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }

  # Custom headers
  custom_headers_config {
    items {
      header   = "X-API-Version"
      value    = "v1"
      override = false
    }

    items {
      header   = "X-Service-Name"
      value    = "squrl"
      override = false
    }

    items {
      header   = "X-Environment"
      value    = var.environment
      override = false
    }

    items {
      header   = "Cache-Control"
      value    = "public, max-age=3600"
      override = false
    }

    # Rate limiting headers (will be overridden by API Gateway/Lambda if present)
    items {
      header   = "X-RateLimit-Limit"
      value    = tostring(var.rate_limit_requests_per_5min)
      override = false
    }

    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), microphone=(), camera=()"
      override = false
    }
  }

  # Server timing (for debugging in non-production)
  dynamic "server_timing_headers_config" {
    for_each = var.environment != "prod" ? [1] : []
    content {
      enabled       = true
      sampling_rate = 10.0 # 10% sampling
    }
  }
}