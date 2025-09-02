# Example of how to use the API Gateway module in your main Terraform configuration
# This file shows the integration with existing Lambda modules

# This would go in your main terraform configuration (e.g., environments/dev/main.tf)

# module "api_gateway" {
#   source = "../../modules/api_gateway"
# 
#   # Basic configuration
#   api_name    = "squrl-api"
#   environment = var.environment
#   stage_name  = "v1"
# 
#   # Lambda function integration - using outputs from existing lambda modules
#   create_url_lambda_arn         = module.create_url_lambda.function_arn
#   create_url_lambda_invoke_arn  = module.create_url_lambda.invoke_arn
#   redirect_lambda_arn           = module.redirect_lambda.function_arn  
#   redirect_lambda_invoke_arn    = module.redirect_lambda.invoke_arn
#   get_stats_lambda_arn          = module.get_stats_lambda.function_arn
#   get_stats_lambda_invoke_arn   = module.get_stats_lambda.invoke_arn
# 
#   # Rate limiting configuration (as per milestone-02.md specs)
#   throttle_burst_limit = 200  # 200 req/sec burst
#   throttle_rate_limit  = 100  # 100 req/sec sustained
# 
#   # Environment-specific configurations
#   enable_access_logs   = var.environment != "dev"  # Enable in staging/prod
#   enable_xray_tracing  = true
#   log_retention_days   = var.environment == "prod" ? 30 : 14
# 
#   # Optional quota settings (can be added for additional protection)
#   # quota_limit  = 10000  # 10k requests per day
#   # quota_period = "DAY"
# 
#   tags = local.common_tags
# }
# 
# # Output the API endpoint for use by other resources or for documentation
# output "api_endpoint" {
#   description = "API Gateway endpoint URL"
#   value       = module.api_gateway.invoke_url
# }
# 
# output "api_endpoints" {
#   description = "All API endpoints"
#   value = {
#     create_url = module.api_gateway.create_url_endpoint
#     redirect   = module.api_gateway.redirect_url_base
#     stats      = module.api_gateway.stats_url_base
#   }
# }
# 
# # For CloudFront integration (in future milestone)
# output "api_gateway_domain_name" {
#   description = "API Gateway domain name for CloudFront origin"
#   value       = replace(module.api_gateway.invoke_url, "https://", "")
# }