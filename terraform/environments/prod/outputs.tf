# Core Infrastructure Outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"  
  value       = aws_api_gateway_rest_api.squrl.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "lambda_function_names" {
  description = "Lambda function names"
  value = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    get_stats  = module.get_stats_lambda.function_name
  }
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}


output "s3_bucket_name" {
  description = "S3 bucket name for web hosting"
  value       = module.static_hosting.bucket_name
}