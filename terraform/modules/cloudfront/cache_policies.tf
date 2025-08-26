# Cache Policy for API Default Behavior (minimal caching)
resource "aws_cloudfront_cache_policy" "api_default" {
  name        = "squrl-api-default-${var.environment}"
  comment     = "Cache policy for general API endpoints"
  default_ttl = var.default_cache_ttl_seconds
  max_ttl     = var.default_cache_ttl_seconds * 2
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = var.enable_compression
    enable_accept_encoding_gzip   = var.enable_compression

    query_strings_config {
      query_string_behavior = "all"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Accept",
          "Accept-Language", 
          "Authorization",
          "Content-Type",
          "User-Agent",
          "X-Forwarded-For"
        ]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache Policy for URL Redirects (cache for 1 hour)
resource "aws_cloudfront_cache_policy" "redirect" {
  name        = "squrl-redirect-${var.environment}"
  comment     = "Cache policy for URL redirects - optimized for high cache hit rate"
  default_ttl = var.redirect_cache_ttl_seconds
  max_ttl     = var.redirect_cache_ttl_seconds * 24 # Allow up to 24 hours
  min_ttl     = var.redirect_cache_ttl_seconds / 2  # Minimum 30 minutes

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false # Redirects don't need compression
    enable_accept_encoding_gzip   = false

    query_strings_config {
      query_string_behavior = "none" # Ignore query strings for redirects
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "User-Agent", # For analytics
          "Referer"     # For analytics
        ]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache Policy for /create endpoint (no caching)
resource "aws_cloudfront_cache_policy" "no_cache" {
  name        = "squrl-no-cache-${var.environment}"
  comment     = "No caching policy for create endpoint"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    query_strings_config {
      query_string_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Cache Policy for /stats endpoint (cache for 5 minutes)
resource "aws_cloudfront_cache_policy" "stats" {
  name        = "squrl-stats-${var.environment}"
  comment     = "Cache policy for stats endpoint - short cache for near real-time data"
  default_ttl = 300  # 5 minutes
  max_ttl     = 3600 # 1 hour max
  min_ttl     = 60   # 1 minute min

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = var.enable_compression
    enable_accept_encoding_gzip   = var.enable_compression

    query_strings_config {
      query_string_behavior = "all" # Include query params in cache key
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Accept",
          "Accept-Language",
          "Authorization",
          "User-Agent"
        ]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}