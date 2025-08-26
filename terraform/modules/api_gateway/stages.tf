# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_method.create_post,
    aws_api_gateway_integration.create_post,
    aws_api_gateway_method.redirect_get,
    aws_api_gateway_integration.redirect_get,
    aws_api_gateway_method.stats_get,
    aws_api_gateway_integration.stats_get,
    aws_api_gateway_method.options,
    aws_api_gateway_integration.options
  ]

  rest_api_id = aws_api_gateway_rest_api.squrl_api.id

  triggers = {
    # Redeploy when any of these change
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.create.id,
      aws_api_gateway_resource.short_code.id,
      aws_api_gateway_resource.stats.id,
      aws_api_gateway_resource.stats_short_code.id,
      aws_api_gateway_method.create_post.id,
      aws_api_gateway_method.redirect_get.id,
      aws_api_gateway_method.stats_get.id,
      aws_api_gateway_integration.create_post.id,
      aws_api_gateway_integration.redirect_get.id,
      aws_api_gateway_integration.stats_get.id,
      aws_api_gateway_model.create_url_request.id,
      aws_api_gateway_model.create_url_response.id,
      aws_api_gateway_model.stats_response.id,
      aws_api_gateway_model.error_response.id,
      var.create_url_lambda_invoke_arn,
      var.redirect_lambda_invoke_arn,
      var.analytics_lambda_invoke_arn,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Main API Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  stage_name    = var.stage_name

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

  # Access logging configuration
  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway_access[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
        requestLength  = "$context.requestLength"
        responseTime   = "$context.responseTime"
        errorMessage   = "$context.error.message"
        errorType      = "$context.error.messageString"
        sourceIp       = "$context.identity.sourceIp"
        userAgent      = "$context.identity.userAgent"
        apiId          = "$context.apiId"
        stage          = "$context.stage"
        integration = {
          error             = "$context.integration.error"
          integrationStatus = "$context.integration.integrationStatus"
          latency           = "$context.integration.latency"
          requestId         = "$context.integration.requestId"
          responseLatency   = "$context.integration.responseLatency"
          status            = "$context.integration.status"
        }
      })
    }
  }

  # Stage variables (can be used in Lambda integrations)
  variables = {
    environment  = var.environment
    version      = "v1"
    lambda_alias = var.environment == "prod" ? "LIVE" : "LATEST"
  }

  tags = merge(var.tags, {
    Stage = var.stage_name
  })
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.squrl_api.name}/access"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Base path mapping (if custom domain is used later)
# resource "aws_api_gateway_base_path_mapping" "main" {
#   count       = var.custom_domain_name != null ? 1 : 0
#   api_id      = aws_api_gateway_rest_api.squrl_api.id
#   stage_name  = aws_api_gateway_stage.main.stage_name
#   domain_name = var.custom_domain_name
#   base_path   = var.base_path
# }

# WAF Web ACL Association (if WAF is configured)
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count        = var.web_acl_arn != null ? 1 : 0
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = var.web_acl_arn
}

# API Gateway Domain Name (for custom domain support in the future)
# resource "aws_api_gateway_domain_name" "main" {
#   count                    = var.custom_domain_name != null ? 1 : 0
#   domain_name              = var.custom_domain_name
#   regional_certificate_arn = var.certificate_arn
#   
#   endpoint_configuration {
#     types = ["REGIONAL"]
#   }
#   
#   tags = var.tags
# }

# Route53 record for custom domain (if used)
# resource "aws_route53_record" "api" {
#   count   = var.custom_domain_name != null && var.hosted_zone_id != null ? 1 : 0
#   name    = aws_api_gateway_domain_name.main[0].domain_name
#   type    = "A"
#   zone_id = var.hosted_zone_id
#   
#   alias {
#     evaluate_target_health = false
#     name                   = aws_api_gateway_domain_name.main[0].regional_domain_name
#     zone_id                = aws_api_gateway_domain_name.main[0].regional_zone_id
#   }
# }