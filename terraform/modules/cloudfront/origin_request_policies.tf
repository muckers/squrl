# Origin Request Policy for API Default Behavior
resource "aws_cloudfront_origin_request_policy" "api_default" {
  name    = "squrl-api-default-${var.environment}"
  comment = "Origin request policy for general API endpoints"

  query_strings_config {
    query_string_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Accept",
        "Content-Type",
        "Host",
        "Origin",
        "Referer",
        "User-Agent",
        "X-Forwarded-For"
      ]
    }
  }

  cookies_config {
    cookie_behavior = "none"
  }
}

# Origin Request Policy for URL Redirects
resource "aws_cloudfront_origin_request_policy" "redirect" {
  name    = "squrl-redirect-${var.environment}"
  comment = "Origin request policy for URL redirects - minimal forwarding for performance"

  query_strings_config {
    query_string_behavior = "none" # Don't forward query strings for redirects
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "CloudFront-Viewer-Country",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Is-Tablet-Viewer",
        "Host",
        "Referer",
        "User-Agent",
        "X-Forwarded-For"
      ]
    }
  }

  cookies_config {
    cookie_behavior = "none"
  }
}