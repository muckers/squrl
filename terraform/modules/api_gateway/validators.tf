# Request validator for create URL endpoint
resource "aws_api_gateway_request_validator" "create_url" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  name        = "${var.api_name}-${var.environment}-create-url-validator"

  validate_request_body       = true
  validate_request_parameters = true
}

# Request validator for parameters only (for GET endpoints)
resource "aws_api_gateway_request_validator" "parameters_only" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  name        = "${var.api_name}-${var.environment}-parameters-validator"

  validate_request_body       = false
  validate_request_parameters = true
}

# ============================================================================
# Request/Response Models
# ============================================================================

# Create URL Request Model
resource "aws_api_gateway_model" "create_url_request" {
  rest_api_id  = aws_api_gateway_rest_api.squrl_api.id
  name         = "CreateUrlRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Create URL Request"
    type      = "object"
    required  = ["url"]
    properties = {
      url = {
        type        = "string"
        pattern     = "^https?://[^\\s/$.?#].[^\\s]*$"
        minLength   = 1
        maxLength   = 2048
        description = "The URL to be shortened. Must be a valid HTTP or HTTPS URL."
      }
      custom_code = {
        type        = "string"
        pattern     = "^[a-zA-Z0-9_-]{3,20}$"
        minLength   = 3
        maxLength   = 20
        description = "Optional custom short code. Must be 3-20 characters, alphanumeric, underscores, and hyphens only."
      }
      expires_at = {
        type        = "string"
        format      = "date-time"
        description = "Optional expiration date in ISO 8601 format (e.g., 2023-12-31T23:59:59Z)."
      }
    }
    additionalProperties = false
  })
}

# Create URL Response Model
resource "aws_api_gateway_model" "create_url_response" {
  rest_api_id  = aws_api_gateway_rest_api.squrl_api.id
  name         = "CreateUrlResponse"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Create URL Response"
    type      = "object"
    required  = ["short_code", "short_url", "original_url", "created_at"]
    properties = {
      short_code = {
        type        = "string"
        description = "The generated short code for the URL"
      }
      short_url = {
        type        = "string"
        format      = "uri"
        description = "The complete shortened URL"
      }
      original_url = {
        type        = "string"
        format      = "uri"
        description = "The original URL that was shortened"
      }
      created_at = {
        type        = "string"
        format      = "date-time"
        description = "Timestamp when the URL was created"
      }
      expires_at = {
        type        = "string"
        format      = "date-time"
        description = "Optional expiration timestamp"
      }
      click_count = {
        type        = "integer"
        minimum     = 0
        description = "Current number of clicks/redirects"
      }
    }
    additionalProperties = false
  })
}

# Stats Response Model
resource "aws_api_gateway_model" "stats_response" {
  rest_api_id  = aws_api_gateway_rest_api.squrl_api.id
  name         = "StatsResponse"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Stats Response"
    type      = "object"
    required  = ["short_code", "original_url", "created_at", "click_count"]
    properties = {
      short_code = {
        type        = "string"
        description = "The short code"
      }
      original_url = {
        type        = "string"
        format      = "uri"
        description = "The original URL"
      }
      created_at = {
        type        = "string"
        format      = "date-time"
        description = "When the URL was created"
      }
      expires_at = {
        type        = "string"
        format      = "date-time"
        description = "Optional expiration timestamp"
      }
      click_count = {
        type        = "integer"
        minimum     = 0
        description = "Total number of clicks/redirects"
      }
      last_accessed = {
        type        = "string"
        format      = "date-time"
        description = "Timestamp of last access"
      }
      analytics = {
        type        = "object"
        description = "Additional analytics data"
        properties = {
          daily_clicks = {
            type        = "array"
            description = "Daily click counts for the last 30 days"
            items = {
              type     = "object"
              required = ["date", "count"]
              properties = {
                date = {
                  type        = "string"
                  format      = "date"
                  description = "Date in YYYY-MM-DD format"
                }
                count = {
                  type        = "integer"
                  minimum     = 0
                  description = "Number of clicks on this date"
                }
              }
            }
          }
          top_referrers = {
            type        = "array"
            description = "Top 10 referring domains"
            items = {
              type     = "object"
              required = ["referrer", "count"]
              properties = {
                referrer = {
                  type        = "string"
                  description = "Referring domain or 'direct' for direct access"
                }
                count = {
                  type        = "integer"
                  minimum     = 0
                  description = "Number of clicks from this referrer"
                }
              }
            }
          }
          geographic_distribution = {
            type        = "array"
            description = "Geographic distribution of clicks by country"
            items = {
              type     = "object"
              required = ["country", "count"]
              properties = {
                country = {
                  type        = "string"
                  description = "Country code (ISO 3166-1 alpha-2)"
                }
                count = {
                  type        = "integer"
                  minimum     = 0
                  description = "Number of clicks from this country"
                }
              }
            }
          }
        }
        additionalProperties = false
      }
    }
    additionalProperties = false
  })
}

# Error Response Model
resource "aws_api_gateway_model" "error_response" {
  rest_api_id  = aws_api_gateway_rest_api.squrl_api.id
  name         = "ErrorResponse"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Error Response"
    type      = "object"
    required  = ["error", "message"]
    properties = {
      error = {
        type        = "string"
        description = "Error type or code"
      }
      message = {
        type        = "string"
        description = "Human-readable error message"
      }
      details = {
        type                 = "object"
        description          = "Additional error details"
        additionalProperties = true
      }
      timestamp = {
        type        = "string"
        format      = "date-time"
        description = "Timestamp when the error occurred"
      }
      request_id = {
        type        = "string"
        description = "Unique identifier for the request"
      }
    }
    additionalProperties = false
  })
}