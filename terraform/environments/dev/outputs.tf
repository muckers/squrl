output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.squrl.id
}

# ========================================
# Legacy outputs (for backward compatibility)
# ========================================

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "lambda_function_names" {
  description = "Lambda function names"
  value = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    analytics  = module.analytics_lambda.function_name
  }
}

output "kinesis_stream_name" {
  description = "Kinesis stream name"
  value       = aws_kinesis_stream.analytics.name
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "cloudfront_url" {
  description = "Full CloudFront URL"
  value       = module.cloudfront.cloudfront_url
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.cloudfront.web_acl_id
}

output "cloudfront_status" {
  description = "CloudFront distribution deployment status"
  value       = module.cloudfront.status
}

# Monitoring outputs
output "monitoring_dashboard_urls" {
  description = "CloudWatch dashboard URLs"
  value       = module.monitoring.dashboard_urls
}

output "monitoring_dashboard_names" {
  description = "CloudWatch dashboard names"
  value       = module.monitoring.dashboard_names
}

output "alerts_sns_topic_arn" {
  description = "SNS topic ARN for monitoring alerts"
  value       = module.monitoring.alerts_sns_topic_arn
}

output "all_alarm_names" {
  description = "All CloudWatch alarm names"
  value       = module.monitoring.all_alarm_names
}

output "critical_alarms" {
  description = "Critical CloudWatch alarm names"
  value       = module.monitoring.critical_alarms
}

output "monitoring_configuration" {
  description = "Monitoring configuration summary"
  value       = module.monitoring.monitoring_config
}

# ========================================
# Security Module Outputs
# ========================================

# KMS Module Outputs
output "kms_key_arns" {
  description = "Map of service names to KMS key ARNs"
  value       = module.kms.all_key_arns
}

output "kms_key_aliases" {
  description = "Map of service names to KMS key aliases"
  value       = module.kms.all_key_aliases
}

output "kms_enabled_services" {
  description = "List of services with KMS encryption enabled"
  value       = module.kms.enabled_services
}

# Secrets Manager Module Outputs
output "secrets_manager_secret_arns" {
  description = "Map of secret names to their ARNs"
  value       = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? module.secrets_manager[0].secret_arns : {}
  sensitive   = true
}

output "secrets_manager_secret_names" {
  description = "Map of secret keys to their full names in Secrets Manager"
  value       = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? module.secrets_manager[0].secret_names : {}
}

output "secrets_manager_lambda_policy_arn" {
  description = "ARN of the IAM policy for Lambda to read secrets"
  value       = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? module.secrets_manager[0].lambda_secrets_read_policy_arn : null
}

# Parameter Store Module Outputs
output "parameter_store_parameter_arns" {
  description = "Map of parameter names to their ARNs"
  value       = var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].parameter_arns : {}
}

output "parameter_store_parameter_names" {
  description = "Map of parameter keys to their full SSM parameter names"
  value       = var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].parameter_names : {}
}

output "parameter_store_read_policy_arn" {
  description = "ARN of the IAM policy for reading parameters"
  value       = var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].parameter_read_policy_arn : null
}

output "parameter_store_hierarchy_root" {
  description = "Root path for all parameters"
  value       = var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].parameter_hierarchy_root : null
}

# API Gateway WAF Module Outputs
output "api_gateway_waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL for API Gateway"
  value       = var.enable_api_gateway_waf && length(module.api_gateway_waf) > 0 ? module.api_gateway_waf[0].web_acl_arn : null
}

output "api_gateway_waf_web_acl_id" {
  description = "ID of the WAF Web ACL for API Gateway"
  value       = var.enable_api_gateway_waf && length(module.api_gateway_waf) > 0 ? module.api_gateway_waf[0].web_acl_id : null
}

output "api_gateway_waf_configuration" {
  description = "Summary of WAF configuration"
  value       = var.enable_api_gateway_waf && length(module.api_gateway_waf) > 0 ? module.api_gateway_waf[0].waf_configuration : null
}

# VPC Endpoints Module Outputs
output "vpc_endpoints_vpc_id" {
  description = "ID of the VPC created for endpoints"
  value       = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].vpc_id : null
}

output "vpc_endpoints_private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].private_subnet_ids : []
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].vpc_endpoints_security_group_id : null
}

output "vpc_endpoints_enabled" {
  description = "List of enabled VPC endpoints"
  value       = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].all_vpc_endpoint_ids : []
}

output "vpc_endpoints_estimated_monthly_cost" {
  description = "Estimated monthly cost for VPC endpoints"
  value       = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].estimated_monthly_cost : null
}

# ========================================
# Security Configuration Summary
# ========================================

output "security_configuration" {
  description = "Summary of security configurations enabled"
  value = {
    kms = {
      enabled  = true
      services = module.kms.enabled_services
    }
    secrets_manager = {
      enabled      = var.enable_secrets_manager
      secret_count = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? module.secrets_manager[0].secret_count : 0
    }
    parameter_store = {
      enabled         = var.enable_parameter_store
      parameter_count = var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].parameter_count : 0
    }
    api_gateway_waf = {
      enabled = var.enable_api_gateway_waf
    }
    vpc_endpoints = {
      enabled           = var.enable_vpc_endpoints
      endpoint_count    = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? length(module.vpc_endpoints[0].all_vpc_endpoint_ids) : 0
      estimated_cost    = var.enable_vpc_endpoints && length(module.vpc_endpoints) > 0 ? module.vpc_endpoints[0].estimated_monthly_cost : null
    }
  }
}