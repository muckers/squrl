terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "squrl-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# KMS module for encryption - Production configuration with all keys enabled
module "kms" {
  source = "../../modules/kms"

  environment = var.environment
  
  # Enable all keys for production security
  enable_dynamodb_key        = true
  enable_s3_key             = true   # Enable for production data protection
  enable_lambda_key         = true   # Enable for production environment security
  enable_secrets_manager_key = true
  enable_parameter_store_key = true
  enable_kinesis_key        = true
  enable_logs_key           = true   # Enable for production log encryption

  # Production key configuration
  enable_key_rotation = true   # Enable automatic key rotation for production
  key_deletion_window = 30     # Standard 30-day deletion window for production

  tags = local.common_tags
}

# Secrets Manager module for API keys and secrets
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment = var.environment
  kms_key_arn = module.kms.secrets_manager_key_arn

  # Production secrets configuration
  secrets = var.application_secrets

  # Enable rotation for production
  enable_automatic_rotation = var.enable_secret_rotation
  create_rotation_lambda    = var.enable_secret_rotation

  tags = local.common_tags
}

# Parameter Store module for configuration
module "parameter_store" {
  source = "../../modules/parameter-store"

  environment = var.environment
  app_name    = "squrl"
  
  # Use KMS key for SecureString parameters
  default_kms_key_id = module.kms.parameter_store_key_id

  # Production parameter configuration
  parameters = var.application_parameters
  
  # Feature flags for production
  feature_flags = var.feature_flags

  # Production-specific settings
  create_parameter_group     = true  # Enable for better organization
  create_write_policy        = false # Restrict writes in production
  enable_parameter_logging   = true  # Enable logging for audit
  parameter_log_retention    = 90    # Longer retention for production

  tags = local.common_tags
}

# Keep existing resources
module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name  = "squrl-urls-${var.environment}"
  environment = var.environment
  kms_key_id  = module.kms.dynamodb_key_arn  # Use customer-managed KMS key
  tags        = local.common_tags
}

module "create_url_lambda" {
  source = "../../modules/lambda"

  function_name       = "squrl-create-url-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/create-url/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  memory_size         = var.create_url_lambda_memory_size
  timeout             = var.create_url_lambda_timeout
  rust_log_level      = var.lambda_log_level
  environment         = var.environment

  # Production Lambda configuration
  kms_key_arn = module.kms.lambda_key_arn

  # Enhanced environment variables for production
  additional_env_vars = merge({
    SHORT_URL_BASE = "https://squrl.pub"
    ENVIRONMENT    = var.environment
  }, 
  module.parameter_store.lambda_environment_variables,
  {
    SECRETS_MANAGER_REGION = var.aws_region
  }
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = values(module.secrets_manager.secret_arns)

  tags = local.common_tags
}

module "redirect_lambda" {
  source = "../../modules/lambda"

  function_name       = "squrl-redirect-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/redirect/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  kinesis_stream_arn  = aws_kinesis_stream.analytics.arn
  memory_size         = var.redirect_lambda_memory_size
  timeout             = var.redirect_lambda_timeout
  rust_log_level      = var.lambda_log_level
  environment         = var.environment

  # Production Lambda configuration
  kms_key_arn = module.kms.lambda_key_arn

  # Enhanced environment variables for production
  additional_env_vars = merge({
    KINESIS_STREAM_NAME = aws_kinesis_stream.analytics.name
    ENVIRONMENT         = var.environment
  }, 
  module.parameter_store.lambda_environment_variables,
  {
    SECRETS_MANAGER_REGION = var.aws_region
  }
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = values(module.secrets_manager.secret_arns)

  tags = local.common_tags
}

module "analytics_lambda" {
  source = "../../modules/lambda"

  function_name            = "squrl-analytics-${var.environment}"
  lambda_zip_path          = "../../../target/lambda/analytics/bootstrap.zip"
  dynamodb_table_name      = module.dynamodb.table_name
  dynamodb_table_arn       = module.dynamodb.table_arn
  kinesis_stream_arn       = aws_kinesis_stream.analytics.arn
  kinesis_read_permissions = true
  memory_size              = var.analytics_lambda_memory_size
  timeout                  = var.analytics_lambda_timeout
  rust_log_level           = var.lambda_log_level
  environment              = var.environment

  # Production Lambda configuration
  kms_key_arn = module.kms.lambda_key_arn

  # Enhanced environment variables for production
  additional_env_vars = merge({
    ENVIRONMENT = var.environment
  }, 
  module.parameter_store.lambda_environment_variables,
  {
    SECRETS_MANAGER_REGION = var.aws_region
  }
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = values(module.secrets_manager.secret_arns)

  tags = local.common_tags
}

resource "aws_kinesis_stream" "analytics" {
  name             = "squrl-analytics-${var.environment}"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_period

  encryption_type = "KMS"
  kms_key_id      = module.kms.kinesis_key_id  # Use customer-managed KMS key

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "analytics_kinesis" {
  event_source_arn  = aws_kinesis_stream.analytics.arn
  function_name     = module.analytics_lambda.function_name
  starting_position = "LATEST"
}

# API Gateway WAF module for security - Production configuration
module "api_gateway_waf" {
  source = "../../modules/api-gateway-waf"

  environment = var.environment
  
  # API Gateway stage ARN will be provided after API Gateway is created
  api_gateway_stage_arn = aws_api_gateway_stage.main.arn
  
  # Production WAF settings (more restrictive)
  enable_waf                               = true
  rate_limit_requests_per_5min             = var.waf_rate_limit_requests_per_5min
  create_rate_limit_requests_per_5min      = var.waf_create_rate_limit_requests_per_5min
  scanner_detection_404_threshold          = var.waf_scanner_detection_404_threshold
  max_request_body_size_kb                 = 32   # Stricter size limit for production
  max_uri_length                           = 1024 # Stricter length limit for production
  
  # Enable security features for production
  enable_geo_restrictions = var.enable_geo_restrictions
  geo_restricted_countries = var.geo_restricted_countries
  enable_bot_control      = var.enable_bot_control
  bot_control_inspection_level = var.bot_control_inspection_level
  enable_waf_logging      = true  # Enable logging for production
  waf_log_retention_days  = var.waf_log_retention_days
  
  # Alarm configuration
  enable_cloudwatch_alarms = true
  alarm_sns_topic_arn      = module.monitoring.alerts_sns_topic_arn

  tags = local.common_tags
}

# VPC Endpoints module for secure AWS service access
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"
  
  count = var.enable_vpc_endpoints ? 1 : 0

  environment = var.environment
  
  # VPC configuration - create production VPC with multiple AZs
  create_vpc = var.create_vpc_for_endpoints
  vpc_cidr   = var.vpc_cidr
  
  # Multi-AZ configuration for high availability
  availability_zones     = var.availability_zones
  private_subnet_cidrs   = var.private_subnet_cidrs
  public_subnet_cidrs    = var.public_subnet_cidrs
  
  # NAT Gateway for internet access (required for Lambda in VPC)
  create_nat_gateway = var.create_nat_gateway
  
  # Enable all necessary endpoints for production
  enable_dynamodb_endpoint        = true   # Gateway endpoint - free
  enable_s3_endpoint             = true   # Gateway endpoint - free
  enable_secrets_manager_endpoint = true   # Interface endpoint - has cost
  enable_parameter_store_endpoint = true   # Interface endpoint - has cost
  enable_kms_endpoint            = true   # Interface endpoint - has cost
  enable_kinesis_endpoint        = true   # Interface endpoint - has cost
  enable_lambda_endpoint         = var.enable_lambda_vpc_endpoint
  enable_logs_endpoint           = true   # Interface endpoint - has cost

  tags = local.common_tags
}

# Simple API Gateway setup
resource "aws_api_gateway_rest_api" "squrl" {
  name        = "squrl-api-${var.environment}"
  description = "Squrl URL Shortener API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Create resource
resource "aws_api_gateway_resource" "create" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  parent_id   = aws_api_gateway_rest_api.squrl.root_resource_id
  path_part   = "create"
}

# POST /create method
resource "aws_api_gateway_method" "create_post" {
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  resource_id   = aws_api_gateway_resource.create.id
  http_method   = "POST"
  authorization = "NONE"
}

# OPTIONS /create method for CORS preflight
resource "aws_api_gateway_method" "create_options" {
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  resource_id   = aws_api_gateway_resource.create.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_post" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.create_url_lambda.invoke_arn
}

# OPTIONS integration for CORS preflight
resource "aws_api_gateway_integration" "create_options" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# OPTIONS method response
resource "aws_api_gateway_method_response" "create_options_200" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_options.http_method
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

# OPTIONS integration response
resource "aws_api_gateway_integration_response" "create_options_200" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_options.http_method
  status_code = aws_api_gateway_method_response.create_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Max-Age"       = "'86400'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "create_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.create_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.squrl.execution_arn}/*/*"
}

# Redirect resource for {short_code}
resource "aws_api_gateway_resource" "redirect" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  parent_id   = aws_api_gateway_rest_api.squrl.root_resource_id
  path_part   = "{short_code}"
}

# GET /{short_code} method
resource "aws_api_gateway_method" "redirect_get" {
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  resource_id   = aws_api_gateway_resource.redirect.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.short_code" = true
  }
}

# HEAD /{short_code} method for URL checking
resource "aws_api_gateway_method" "redirect_head" {
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  resource_id   = aws_api_gateway_resource.redirect.id
  http_method   = "HEAD"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.short_code" = true
  }
}

resource "aws_api_gateway_integration" "redirect_get" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.redirect.id
  http_method = aws_api_gateway_method.redirect_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.redirect_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "redirect_head" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.redirect.id
  http_method = aws_api_gateway_method.redirect_head.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.redirect_lambda.invoke_arn
}

# Lambda permission for redirect API Gateway
resource "aws_lambda_permission" "redirect_api_gateway" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = module.redirect_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.squrl.execution_arn}/*/*"
}

# Stats resource
resource "aws_api_gateway_resource" "stats" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  parent_id   = aws_api_gateway_rest_api.squrl.root_resource_id
  path_part   = "stats"
}

# Stats short_code resource for /stats/{short_code}
resource "aws_api_gateway_resource" "stats_short_code" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  parent_id   = aws_api_gateway_resource.stats.id
  path_part   = "{short_code}"
}

# GET /stats/{short_code} method
resource "aws_api_gateway_method" "stats_get" {
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  resource_id   = aws_api_gateway_resource.stats_short_code.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.short_code" = true
  }
}

resource "aws_api_gateway_integration" "stats_get" {
  rest_api_id = aws_api_gateway_rest_api.squrl.id
  resource_id = aws_api_gateway_resource.stats_short_code.id
  http_method = aws_api_gateway_method.stats_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.analytics_lambda.invoke_arn
}

# Lambda permission for stats API Gateway
resource "aws_lambda_permission" "stats_api_gateway" {
  statement_id  = "AllowAPIGatewayInvokeStats"
  action        = "lambda:InvokeFunction"
  function_name = module.analytics_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.squrl.execution_arn}/*/*"
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.create_post,
    aws_api_gateway_integration.create_options,
    aws_api_gateway_integration_response.create_options_200,
    aws_api_gateway_integration.redirect_get,
    aws_api_gateway_integration.redirect_head,
    aws_api_gateway_integration.stats_get,
  ]

  rest_api_id = aws_api_gateway_rest_api.squrl.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.create.id,
      aws_api_gateway_method.create_post.id,
      aws_api_gateway_integration.create_post.id,
      aws_api_gateway_method.create_options.id,
      aws_api_gateway_integration.create_options.id,
      aws_api_gateway_method_response.create_options_200.id,
      aws_api_gateway_integration_response.create_options_200.id,
      aws_api_gateway_resource.redirect.id,
      aws_api_gateway_method.redirect_get.id,
      aws_api_gateway_integration.redirect_get.id,
      aws_api_gateway_method.redirect_head.id,
      aws_api_gateway_integration.redirect_head.id,
      aws_api_gateway_resource.stats.id,
      aws_api_gateway_resource.stats_short_code.id,
      aws_api_gateway_method.stats_get.id,
      aws_api_gateway_integration.stats_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.squrl.id
  stage_name    = "v1"

  # Enable comprehensive logging and tracing for production
  xray_tracing_enabled = var.enable_xray_tracing
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format = jsonencode({
      requestId              = "$context.requestId"
      extendedRequestId      = "$context.extendedRequestId"
      ip                     = "$context.identity.sourceIp"
      caller                 = "$context.identity.caller"
      user                   = "$context.identity.user"
      requestTime            = "$context.requestTime"
      httpMethod             = "$context.httpMethod"
      resourcePath           = "$context.resourcePath"
      status                 = "$context.status"
      protocol               = "$context.protocol"
      responseLength         = "$context.responseLength"
      requestLength          = "$context.requestLength"
      responseTime           = "$context.responseTime"
      integrationRequestId   = "$context.integration.requestId"
      integrationStatus      = "$context.integration.status"
      integrationLatency     = "$context.integration.latency"
      integrationServiceTime = "$context.integration.integrationStatus"
      userAgent             = "$context.identity.userAgent"
    })
  }

  tags = local.common_tags
}

# CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.squrl.name}"
  retention_in_days = var.api_gateway_log_retention_days
  kms_key_id        = module.kms.logs_key_arn  # Encrypt logs in production
  
  tags = local.common_tags
}

# S3 bucket for static web hosting
module "static_hosting" {
  source = "../../modules/s3-static-hosting"

  bucket_name = "squrl-web-ui-${var.environment}"
  environment = var.environment
  
  # Enhanced security for production
  kms_key_id        = module.kms.s3_key_arn
  enable_versioning = true
  enable_encryption = true
  
  # Enable lifecycle management for cost optimization
  enable_lifecycle_management      = true
  old_version_expiration_days     = 90  # Keep old versions for 90 days
  multipart_upload_cleanup_days   = 7   # Clean up incomplete uploads after 7 days
  
  # Enable notifications for monitoring
  enable_notifications = true

  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  api_gateway_domain_name = "${aws_api_gateway_rest_api.squrl.id}.execute-api.${var.aws_region}.amazonaws.com"
  api_gateway_stage_name  = aws_api_gateway_stage.main.stage_name
  environment             = var.environment

  # S3 static hosting integration
  s3_bucket_name                 = module.static_hosting.bucket_id
  s3_bucket_regional_domain_name = module.static_hosting.bucket_regional_domain_name

  # Custom domain configuration - Production domain
  custom_domain_name = "squrl.pub"
  certificate_arn    = "arn:aws:acm:us-east-1:634280252303:certificate/73c30742-3f2b-4e2c-95b4-f97367ee1514"

  # Enable WAF for production (temporarily disable logging due to CloudWatch log group ARN issue)
  enable_waf_logging = false
  enable_waf         = true

  # Production rate limits
  rate_limit_requests_per_5min        = 50000
  create_rate_limit_requests_per_5min = 5000

  tags = local.common_tags
}

# Monitoring module for dashboards and alarms
module "monitoring" {
  source = "../../modules/monitoring"

  # Basic configuration
  environment  = var.environment
  service_name = "squrl"
  aws_region   = var.aws_region

  # Resource identification
  api_gateway_name           = aws_api_gateway_rest_api.squrl.name
  api_gateway_stage_name     = aws_api_gateway_stage.main.stage_name
  cloudfront_distribution_id = module.cloudfront.distribution_id

  lambda_function_names = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    analytics  = module.analytics_lambda.function_name
  }

  dynamodb_table_name = module.dynamodb.table_name
  kinesis_stream_name = aws_kinesis_stream.analytics.name

  # Alarm configuration for production environment
  enable_alarms         = true
  alarm_email_endpoints = [var.admin_email]

  # Cost thresholds for production
  monthly_cost_threshold_dev  = 50
  monthly_cost_threshold_prod = 500

  # Performance thresholds for production (stricter)
  error_rate_threshold        = 1   # 1% error rate threshold for prod
  latency_p99_threshold_ms    = 100 # 100ms P99 latency threshold
  lambda_throttle_threshold   = 5   # 5 throttle events threshold
  dynamodb_throttle_threshold = 1   # 1 throttle event threshold

  # Abuse detection settings (enabled for production)
  enable_abuse_detection          = true
  abuse_requests_per_ip_threshold = 1000 # 1000 requests per IP threshold
  abuse_urls_per_ip_threshold     = 100  # 100 URLs per IP per hour

  # Dashboard configuration (full monitoring for production)
  enable_dashboards             = true
  enable_xray_tracing           = true # Enable X-Ray for production
  enable_custom_metrics         = true # Enable custom metrics for production
  enable_cost_anomaly_detection = true # Enable cost anomaly detection

  # Log retention for production
  log_retention_days = 30

  tags = local.common_tags
}

# Route53 configuration for squrl.pub domain
data "aws_route53_zone" "main" {
  name         = "squrl.pub"
  private_zone = false
}

# A record pointing squrl.pub to CloudFront
resource "aws_route53_record" "squrl_a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "squrl.pub"
  type    = "A"

  alias {
    name                   = module.cloudfront.domain_name
    zone_id                = module.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [module.cloudfront]
}

# AAAA record for IPv6 support
resource "aws_route53_record" "squrl_aaaa" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "squrl.pub"
  type    = "AAAA"

  alias {
    name                   = module.cloudfront.domain_name
    zone_id                = module.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [module.cloudfront]
}

locals {
  common_tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
    Repository  = "squrl-proto"
    Milestone   = "production"
  }
}