output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.squrl.id
}

# Legacy outputs (for backward compatibility)
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