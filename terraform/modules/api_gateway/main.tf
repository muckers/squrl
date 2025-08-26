# API Gateway REST API
resource "aws_api_gateway_rest_api" "squrl_api" {
  name        = var.api_name
  description = "Squrl URL Shortener API - ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Enable binary media types for potential future use
  binary_media_types = [
    "application/octet-stream",
    "image/*"
  ]

  tags = var.tags
}

# CORS preflight OPTIONS method for all resources
resource "aws_api_gateway_method" "options" {
  for_each = toset([
    aws_api_gateway_resource.create.id,
    aws_api_gateway_resource.short_code.id,
    aws_api_gateway_resource.stats.id
  ])

  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options" {
  for_each = aws_api_gateway_method.options

  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Max-Age"       = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "options" {
  for_each = aws_api_gateway_method.options

  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = aws_api_gateway_integration.options

  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Max-Age"       = "'86400'"
  }

  depends_on = [aws_api_gateway_method_response.options]
}

# Gateway Response for 4XX errors
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
  }
}

# Gateway Response for 5XX errors
resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
  }
}

# CloudWatch logs for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.squrl_api.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}