# API Gateway REST API outputs
output "rest_api_id" {
  description = "The ID of the REST API"
  value       = aws_api_gateway_rest_api.squrl_api.id
}

output "rest_api_arn" {
  description = "The ARN of the REST API"
  value       = aws_api_gateway_rest_api.squrl_api.arn
}

output "rest_api_name" {
  description = "The name of the REST API"
  value       = aws_api_gateway_rest_api.squrl_api.name
}

output "rest_api_root_resource_id" {
  description = "The resource ID of the REST API's root"
  value       = aws_api_gateway_rest_api.squrl_api.root_resource_id
}

output "rest_api_execution_arn" {
  description = "The execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.squrl_api.execution_arn
}

# Stage outputs
output "stage_name" {
  description = "The name of the deployment stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "The ARN of the deployment stage"
  value       = aws_api_gateway_stage.main.arn
}

output "invoke_url" {
  description = "The URL to invoke the API pointing to the stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

# Deployment outputs
output "deployment_id" {
  description = "The ID of the deployment"
  value       = aws_api_gateway_deployment.main.id
}

# Usage Plan outputs
output "usage_plan_id" {
  description = "The ID of the usage plan"
  value       = aws_api_gateway_usage_plan.main.id
}

output "usage_plan_arn" {
  description = "The ARN of the usage plan"
  value       = aws_api_gateway_usage_plan.main.arn
}

output "usage_plan_name" {
  description = "The name of the usage plan"
  value       = aws_api_gateway_usage_plan.main.name
}

# Resource outputs for reference
output "create_resource_id" {
  description = "The ID of the /create resource"
  value       = aws_api_gateway_resource.create.id
}

output "short_code_resource_id" {
  description = "The ID of the /{short_code} resource"
  value       = aws_api_gateway_resource.short_code.id
}

output "stats_resource_id" {
  description = "The ID of the /stats resource"
  value       = aws_api_gateway_resource.stats.id
}

output "stats_short_code_resource_id" {
  description = "The ID of the /stats/{short_code} resource"
  value       = aws_api_gateway_resource.stats_short_code.id
}

# Endpoint URLs for convenience
output "create_url_endpoint" {
  description = "Complete URL for the create endpoint"
  value       = "${aws_api_gateway_stage.main.invoke_url}/create"
}

output "redirect_url_base" {
  description = "Base URL for redirect endpoints (append short_code)"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "stats_url_base" {
  description = "Base URL for stats endpoints (append /stats/{short_code})"
  value       = "${aws_api_gateway_stage.main.invoke_url}/stats"
}

# CloudWatch Log Group outputs
output "api_gateway_log_group_name" {
  description = "Name of the API Gateway CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "api_gateway_log_group_arn" {
  description = "ARN of the API Gateway CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

output "access_log_group_name" {
  description = "Name of the API Gateway access log group"
  value       = var.enable_access_logs ? aws_cloudwatch_log_group.api_gateway_access[0].name : null
}

output "access_log_group_arn" {
  description = "ARN of the API Gateway access log group"
  value       = var.enable_access_logs ? aws_cloudwatch_log_group.api_gateway_access[0].arn : null
}

# IAM Role outputs
output "cloudwatch_role_arn" {
  description = "ARN of the IAM role for CloudWatch logging"
  value       = aws_iam_role.api_gateway_cloudwatch.arn
}

# Model outputs for reference
output "create_url_request_model_name" {
  description = "Name of the create URL request model"
  value       = aws_api_gateway_model.create_url_request.name
}

output "create_url_response_model_name" {
  description = "Name of the create URL response model"
  value       = aws_api_gateway_model.create_url_response.name
}

output "stats_response_model_name" {
  description = "Name of the stats response model"
  value       = aws_api_gateway_model.stats_response.name
}

output "error_response_model_name" {
  description = "Name of the error response model"
  value       = aws_api_gateway_model.error_response.name
}

# Validator outputs
output "create_url_validator_id" {
  description = "ID of the create URL request validator"
  value       = aws_api_gateway_request_validator.create_url.id
}

output "parameters_validator_id" {
  description = "ID of the parameters-only request validator"
  value       = aws_api_gateway_request_validator.parameters_only.id
}

# Configuration summary for documentation
output "api_configuration" {
  description = "Summary of API configuration"
  value = {
    api_name    = aws_api_gateway_rest_api.squrl_api.name
    stage_name  = aws_api_gateway_stage.main.stage_name
    invoke_url  = aws_api_gateway_stage.main.invoke_url
    environment = var.environment
    rate_limiting = {
      burst_limit = var.throttle_burst_limit
      rate_limit  = var.throttle_rate_limit
    }
    endpoints = {
      create_url = "${aws_api_gateway_stage.main.invoke_url}/create"
      redirect   = "${aws_api_gateway_stage.main.invoke_url}/{short_code}"
      stats      = "${aws_api_gateway_stage.main.invoke_url}/stats/{short_code}"
    }
    features = {
      xray_tracing  = var.enable_xray_tracing
      access_logs   = var.enable_access_logs
      cors_enabled  = true
      validation    = true
      rate_limiting = true
    }
  }
}