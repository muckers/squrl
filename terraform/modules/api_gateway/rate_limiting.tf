# Usage Plan for IP-based rate limiting (no API keys required)
resource "aws_api_gateway_usage_plan" "main" {
  name        = coalesce(var.usage_plan_name, "${var.api_name}-${var.environment}")
  description = var.usage_plan_description

  # API throttling configuration
  throttle_settings {
    burst_limit = var.throttle_burst_limit # 200 req/sec burst
    rate_limit  = var.throttle_rate_limit  # 100 req/sec sustained
  }

  # Optional quota settings (can be null)
  dynamic "quota_settings" {
    for_each = var.quota_limit != null ? [1] : []
    content {
      limit  = var.quota_limit
      period = var.quota_period
      offset = var.quota_offset
    }
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.squrl_api.id
    stage  = aws_api_gateway_stage.main.stage_name

    # Per-endpoint throttling configuration
    throttle {
      path        = "/create"
      burst_limit = var.throttle_burst_limit
      rate_limit  = var.throttle_rate_limit
    }

    throttle {
      path        = "/{short_code}"
      burst_limit = var.throttle_burst_limit
      rate_limit  = var.throttle_rate_limit
    }

    throttle {
      path        = "/stats/{short_code}"
      burst_limit = var.throttle_burst_limit
      rate_limit  = var.throttle_rate_limit
    }
  }

  tags = var.tags
}

# Account-level throttling settings (apply to all APIs in the account)
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# IAM role for API Gateway to write to CloudWatch
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.api_name}-${var.environment}-api-gateway-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach CloudWatch logging policy
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Method-level throttling can also be configured via method settings
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    # Enable detailed CloudWatch metrics
    metrics_enabled = true

    # Enable CloudWatch logging
    logging_level      = var.environment == "prod" ? "ERROR" : "INFO"
    data_trace_enabled = var.environment != "prod"

    # Throttling settings at method level
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit

    # Caching settings (disabled by default, can be enabled later)
    caching_enabled      = false
    cache_ttl_in_seconds = 0
# cache_key_parameters not supported in method_settings
  }
}

# Create specific method settings for each endpoint with custom configurations
resource "aws_api_gateway_method_settings" "create_url" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "create/POST"

  settings {
    metrics_enabled    = true
    logging_level      = var.environment == "prod" ? "ERROR" : "INFO"
    data_trace_enabled = var.environment != "prod"

    # Slightly more restrictive for create operations
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit

    # No caching for create operations
    caching_enabled = false
  }
}

resource "aws_api_gateway_method_settings" "redirect" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "{short_code}/GET"

  settings {
    metrics_enabled    = true
    logging_level      = var.environment == "prod" ? "ERROR" : "INFO"
    data_trace_enabled = var.environment != "prod"

    # Higher limits for redirect operations (most common)
    throttling_burst_limit = var.throttle_burst_limit * 2  # 400 burst
    throttling_rate_limit  = var.throttle_rate_limit * 1.5 # 150 sustained

    # Enable short caching for redirect operations
    caching_enabled      = var.environment == "prod"
    cache_ttl_in_seconds = var.environment == "prod" ? 300 : 0 # 5 minutes
# cache_key_parameters not supported in method_settings
  }
}

resource "aws_api_gateway_method_settings" "stats" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "stats/{short_code}/GET"

  settings {
    metrics_enabled    = true
    logging_level      = var.environment == "prod" ? "ERROR" : "INFO"
    data_trace_enabled = var.environment != "prod"

    # Standard limits for stats operations
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit

    # Enable moderate caching for stats
    caching_enabled      = var.environment == "prod"
    cache_ttl_in_seconds = var.environment == "prod" ? 60 : 0 # 1 minute
# cache_key_parameters not supported in method_settings
  }
}