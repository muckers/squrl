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
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# KMS module for encryption
module "kms" {
  source = "../../modules/kms"

  environment = var.environment
  
  # Enable keys for required services
  enable_dynamodb_key        = true
  enable_s3_key             = false  # Cost optimization for dev
  enable_lambda_key         = false  # Cost optimization for dev
  enable_secrets_manager_key = var.enable_secrets_manager
  enable_parameter_store_key = var.enable_parameter_store
  enable_kinesis_key        = true   # Required for analytics
  enable_logs_key           = false  # Use monitoring module's KMS key

  # Key configuration for dev
  enable_key_rotation = false  # Disable rotation for dev to save costs
  key_deletion_window = 7      # Shorter window for dev

  tags = local.common_tags
}

# Secrets Manager module for API keys and secrets
module "secrets_manager" {
  source = "../../modules/secrets-manager"
  
  count = var.enable_secrets_manager ? 1 : 0

  environment = var.environment
  kms_key_arn = module.kms.secrets_manager_key_arn

  # Development secrets configuration (minimal for cost savings)
  secrets = var.application_secrets

  # Cost optimization for dev
  enable_automatic_rotation = false
  create_rotation_lambda    = false

  tags = local.common_tags
}

# Parameter Store module for configuration
module "parameter_store" {
  source = "../../modules/parameter-store"
  
  count = var.enable_parameter_store ? 1 : 0

  environment = var.environment
  app_name    = "squrl"
  
  # Use KMS key for SecureString parameters if available
  default_kms_key_id = module.kms.parameter_store_key_id

  # Development parameter configuration
  parameters = var.application_parameters
  
  # Feature flags for development
  feature_flags = var.feature_flags

  # Development-specific settings
  create_parameter_group     = false  # Cost optimization
  create_write_policy        = true   # Allow updates in dev
  enable_parameter_logging   = false  # Cost optimization
  parameter_log_retention    = 7      # Shorter retention

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
  memory_size         = 256
  timeout             = 10
  rust_log_level      = "info"
  environment         = var.environment

  # KMS key for environment variable encryption (if available)
  kms_key_arn = module.kms.lambda_key_arn

  additional_env_vars = merge({
    SHORT_URL_BASE = "https://staging.squrl.pub"
  }, 
  var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].lambda_environment_variables : {},
  var.enable_secrets_manager && length(module.secrets_manager) > 0 ? {
    SECRETS_MANAGER_REGION = var.aws_region
  } : {}
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? values(module.secrets_manager[0].secret_arns) : []

  tags = local.common_tags
}

module "redirect_lambda" {
  source = "../../modules/lambda"

  function_name       = "squrl-redirect-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/redirect/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  kinesis_stream_arn  = aws_kinesis_stream.analytics.arn
  memory_size         = 128
  timeout             = 5
  rust_log_level      = "info"
  environment         = var.environment

  # KMS key for environment variable encryption (if available)
  kms_key_arn = module.kms.lambda_key_arn

  additional_env_vars = merge({
    KINESIS_STREAM_NAME = aws_kinesis_stream.analytics.name
  }, 
  var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].lambda_environment_variables : {},
  var.enable_secrets_manager && length(module.secrets_manager) > 0 ? {
    SECRETS_MANAGER_REGION = var.aws_region
  } : {}
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? values(module.secrets_manager[0].secret_arns) : []

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
  memory_size              = 512
  timeout                  = 30
  rust_log_level           = "info"
  environment              = var.environment

  # KMS key for environment variable encryption (if available)
  kms_key_arn = module.kms.lambda_key_arn

  additional_env_vars = merge({},
  var.enable_parameter_store && length(module.parameter_store) > 0 ? module.parameter_store[0].lambda_environment_variables : {},
  var.enable_secrets_manager && length(module.secrets_manager) > 0 ? {
    SECRETS_MANAGER_REGION = var.aws_region
  } : {}
  )

  # Pass Secrets Manager ARNs for access (supported by lambda module)
  secrets_manager_arns = var.enable_secrets_manager && length(module.secrets_manager) > 0 ? values(module.secrets_manager[0].secret_arns) : []

  tags = local.common_tags
}

resource "aws_kinesis_stream" "analytics" {
  name             = "squrl-analytics-${var.environment}"
  shard_count      = 1
  retention_period = 24

  encryption_type = "KMS"
  kms_key_id      = module.kms.kinesis_key_id  # Use customer-managed KMS key

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "analytics_kinesis" {
  event_source_arn  = aws_kinesis_stream.analytics.arn
  function_name     = module.analytics_lambda.function_name
  starting_position = "LATEST"
}

# API Gateway WAF module for security
module "api_gateway_waf" {
  source = "../../modules/api-gateway-waf"
  
  count = var.enable_api_gateway_waf ? 1 : 0

  environment = var.environment
  
  # API Gateway stage ARN will be provided after API Gateway is created
  api_gateway_stage_arn = aws_api_gateway_stage.main.arn
  
  # Development-friendly WAF settings (more permissive)
  enable_waf                               = true
  rate_limit_requests_per_5min             = var.waf_rate_limit_requests_per_5min
  create_rate_limit_requests_per_5min      = var.waf_create_rate_limit_requests_per_5min
  scanner_detection_404_threshold          = 50   # More lenient for dev
  max_request_body_size_kb                 = 64   # Standard size
  max_uri_length                           = 2048 # Standard length
  
  # Disable expensive features for dev
  enable_geo_restrictions = false
  enable_bot_control     = false
  enable_waf_logging     = false  # Cost optimization
  
  # Alarm configuration
  enable_cloudwatch_alarms = var.enable_monitoring_alarms
  alarm_sns_topic_arn      = var.enable_monitoring_alarms ? module.monitoring.alerts_sns_topic_arn : null

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

  # Enable logging and tracing for development monitoring
  xray_tracing_enabled = false  # Disable X-Ray in dev to save costs
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.common_tags
}

# CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.squrl.name}"
  retention_in_days = 7  # Short retention for dev
  
  tags = local.common_tags
}

# S3 bucket for static web hosting
module "static_hosting" {
  source = "../../modules/s3-static-hosting"

  bucket_name  = "squrl-web-ui-${var.environment}"
  environment  = var.environment
  
  tags = local.common_tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  api_gateway_domain_name = "${aws_api_gateway_rest_api.squrl.id}.execute-api.${var.aws_region}.amazonaws.com"
  api_gateway_stage_name  = aws_api_gateway_stage.main.stage_name
  environment             = var.environment
  
  # S3 static hosting integration
  s3_bucket_name                    = module.static_hosting.bucket_id
  s3_bucket_regional_domain_name    = module.static_hosting.bucket_regional_domain_name
  
  # Custom domain configuration
  custom_domain_name = "staging.squrl.pub"
  certificate_arn    = "arn:aws:acm:us-east-1:634280252303:certificate/73c30742-3f2b-4e2c-95b4-f97367ee1514"
  
  # Disable WAF logging to simplify initial deployment
  enable_waf_logging = false
  
  # Temporarily disable WAF to test CloudFront configuration
  enable_waf = false
  
  # More permissive rate limits for testing
  rate_limit_requests_per_5min = 10000
  create_rate_limit_requests_per_5min = 1000

  tags = local.common_tags
}

# VPC Endpoints module (optional for dev, cost-conscious)
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"
  
  count = var.enable_vpc_endpoints ? 1 : 0

  environment = var.environment
  
  # VPC configuration - create minimal VPC for dev
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"
  
  # Subnet configuration - single AZ for cost optimization
  availability_zones     = ["${var.aws_region}a"]
  private_subnet_cidrs   = ["10.0.1.0/24"]
  public_subnet_cidrs    = ["10.0.101.0/24"]
  
  # NAT Gateway for internet access (required for Lambda in VPC)
  create_nat_gateway = true
  
  # Enable only essential endpoints for dev to minimize costs
  enable_dynamodb_endpoint        = true   # Gateway endpoint - free
  enable_s3_endpoint             = true   # Gateway endpoint - free
  enable_secrets_manager_endpoint = var.enable_secrets_manager && var.enable_vpc_endpoints_full
  enable_parameter_store_endpoint = var.enable_parameter_store && var.enable_vpc_endpoints_full
  enable_kms_endpoint            = var.enable_vpc_endpoints_full
  enable_kinesis_endpoint        = var.enable_vpc_endpoints_full
  enable_lambda_endpoint         = false  # Not needed in dev
  enable_logs_endpoint           = false  # Cost optimization for dev

  tags = local.common_tags
}

# Monitoring module for dashboards and alarms
module "monitoring" {
  source = "../../modules/monitoring"

  # Basic configuration
  environment         = var.environment
  service_name        = "squrl"
  aws_region         = var.aws_region
  
  # Resource identification
  api_gateway_name               = aws_api_gateway_rest_api.squrl.name
  api_gateway_stage_name         = aws_api_gateway_stage.main.stage_name
  cloudfront_distribution_id     = module.cloudfront.distribution_id
  
  lambda_function_names = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    analytics  = module.analytics_lambda.function_name
  }
  
  dynamodb_table_name = module.dynamodb.table_name
  kinesis_stream_name = aws_kinesis_stream.analytics.name
  
  # Alarm configuration for dev environment
  enable_alarms            = var.enable_monitoring_alarms
  alarm_email_endpoints    = var.enable_monitoring_alarms ? [var.admin_email] : []
  
  # Cost thresholds appropriate for dev
  monthly_cost_threshold_dev  = var.monthly_cost_threshold_dev
  monthly_cost_threshold_prod = 500
  
  # Performance thresholds for dev (more lenient)
  error_rate_threshold           = var.error_rate_threshold
  latency_p99_threshold_ms       = var.latency_p99_threshold_ms
  lambda_throttle_threshold      = 5   # 5 throttle events threshold
  dynamodb_throttle_threshold    = 1   # 1 throttle event threshold
  
  # Abuse detection settings (simplified for dev)
  enable_abuse_detection             = false  # Disable for now to fix deployment issues
  abuse_requests_per_ip_threshold    = 1000  # 1000 requests per IP threshold
  abuse_urls_per_ip_threshold        = 100   # 100 URLs per IP per hour
  
  # Dashboard configuration (simplified for dev)
  enable_dashboards     = var.enable_monitoring_dashboards
  enable_xray_tracing   = false  # Disable X-Ray for dev to reduce costs
  enable_custom_metrics = false  # Disable complex custom metrics for dev
  enable_cost_anomaly_detection = false  # Disable for now
  
  # Log retention for dev (shorter retention to save costs)
  log_retention_days = var.log_retention_days

  tags = local.common_tags
}

locals {
  common_tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
    Repository  = "squrl-proto"
    Milestone   = "milestone-02"
  }
}