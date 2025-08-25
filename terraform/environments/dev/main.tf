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

module "dynamodb" {
  source = "../../modules/dynamodb"
  
  table_name  = "squrl-urls-${var.environment}"
  environment = var.environment
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
  
  additional_env_vars = {
    KINESIS_STREAM_NAME = aws_kinesis_stream.analytics.name
  }
  
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
  
  tags = local.common_tags
}

resource "aws_kinesis_stream" "analytics" {
  name             = "squrl-analytics-${var.environment}"
  shard_count      = 1
  retention_period = 24
  
  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"
  
  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "analytics_kinesis" {
  event_source_arn  = aws_kinesis_stream.analytics.arn
  function_name     = module.analytics_lambda.function_name
  starting_position = "LATEST"
}

locals {
  common_tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
    Repository  = "squrl-proto"
  }
}