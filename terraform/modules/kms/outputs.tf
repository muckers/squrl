# Outputs for KMS encryption module

# ========================================
# DynamoDB KMS Key Outputs
# ========================================

output "dynamodb_key_id" {
  description = "The globally unique identifier for the DynamoDB KMS key"
  value       = var.enable_dynamodb_key ? aws_kms_key.dynamodb[0].key_id : null
}

output "dynamodb_key_arn" {
  description = "The Amazon Resource Name (ARN) of the DynamoDB KMS key"
  value       = var.enable_dynamodb_key ? aws_kms_key.dynamodb[0].arn : null
}

output "dynamodb_key_alias" {
  description = "The alias of the DynamoDB KMS key"
  value       = var.enable_dynamodb_key ? aws_kms_alias.dynamodb[0].name : null
}

output "dynamodb_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the DynamoDB KMS key alias"
  value       = var.enable_dynamodb_key ? aws_kms_alias.dynamodb[0].arn : null
}

# ========================================
# S3 KMS Key Outputs
# ========================================

output "s3_key_id" {
  description = "The globally unique identifier for the S3 KMS key"
  value       = var.enable_s3_key ? aws_kms_key.s3[0].key_id : null
}

output "s3_key_arn" {
  description = "The Amazon Resource Name (ARN) of the S3 KMS key"
  value       = var.enable_s3_key ? aws_kms_key.s3[0].arn : null
}

output "s3_key_alias" {
  description = "The alias of the S3 KMS key"
  value       = var.enable_s3_key ? aws_kms_alias.s3[0].name : null
}

output "s3_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the S3 KMS key alias"
  value       = var.enable_s3_key ? aws_kms_alias.s3[0].arn : null
}

# ========================================
# Lambda KMS Key Outputs
# ========================================

output "lambda_key_id" {
  description = "The globally unique identifier for the Lambda KMS key"
  value       = var.enable_lambda_key ? aws_kms_key.lambda[0].key_id : null
}

output "lambda_key_arn" {
  description = "The Amazon Resource Name (ARN) of the Lambda KMS key"
  value       = var.enable_lambda_key ? aws_kms_key.lambda[0].arn : null
}

output "lambda_key_alias" {
  description = "The alias of the Lambda KMS key"
  value       = var.enable_lambda_key ? aws_kms_alias.lambda[0].name : null
}

output "lambda_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the Lambda KMS key alias"
  value       = var.enable_lambda_key ? aws_kms_alias.lambda[0].arn : null
}

# ========================================
# Secrets Manager KMS Key Outputs
# ========================================

output "secrets_manager_key_id" {
  description = "The globally unique identifier for the Secrets Manager KMS key"
  value       = var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].key_id : null
}

output "secrets_manager_key_arn" {
  description = "The Amazon Resource Name (ARN) of the Secrets Manager KMS key"
  value       = var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].arn : null
}

output "secrets_manager_key_alias" {
  description = "The alias of the Secrets Manager KMS key"
  value       = var.enable_secrets_manager_key ? aws_kms_alias.secrets_manager[0].name : null
}

output "secrets_manager_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the Secrets Manager KMS key alias"
  value       = var.enable_secrets_manager_key ? aws_kms_alias.secrets_manager[0].arn : null
}

# ========================================
# Parameter Store KMS Key Outputs
# ========================================

output "parameter_store_key_id" {
  description = "The globally unique identifier for the Parameter Store KMS key"
  value       = var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].key_id : null
}

output "parameter_store_key_arn" {
  description = "The Amazon Resource Name (ARN) of the Parameter Store KMS key"
  value       = var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].arn : null
}

output "parameter_store_key_alias" {
  description = "The alias of the Parameter Store KMS key"
  value       = var.enable_parameter_store_key ? aws_kms_alias.parameter_store[0].name : null
}

output "parameter_store_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the Parameter Store KMS key alias"
  value       = var.enable_parameter_store_key ? aws_kms_alias.parameter_store[0].arn : null
}

# ========================================
# Kinesis KMS Key Outputs
# ========================================

output "kinesis_key_id" {
  description = "The globally unique identifier for the Kinesis KMS key"
  value       = var.enable_kinesis_key ? aws_kms_key.kinesis[0].key_id : null
}

output "kinesis_key_arn" {
  description = "The Amazon Resource Name (ARN) of the Kinesis KMS key"
  value       = var.enable_kinesis_key ? aws_kms_key.kinesis[0].arn : null
}

output "kinesis_key_alias" {
  description = "The alias of the Kinesis KMS key"
  value       = var.enable_kinesis_key ? aws_kms_alias.kinesis[0].name : null
}

output "kinesis_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the Kinesis KMS key alias"
  value       = var.enable_kinesis_key ? aws_kms_alias.kinesis[0].arn : null
}

# ========================================
# CloudWatch Logs KMS Key Outputs
# ========================================

output "logs_key_id" {
  description = "The globally unique identifier for the CloudWatch Logs KMS key"
  value       = var.enable_logs_key ? aws_kms_key.logs[0].key_id : null
}

output "logs_key_arn" {
  description = "The Amazon Resource Name (ARN) of the CloudWatch Logs KMS key"
  value       = var.enable_logs_key ? aws_kms_key.logs[0].arn : null
}

output "logs_key_alias" {
  description = "The alias of the CloudWatch Logs KMS key"
  value       = var.enable_logs_key ? aws_kms_alias.logs[0].name : null
}

output "logs_key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the CloudWatch Logs KMS key alias"
  value       = var.enable_logs_key ? aws_kms_alias.logs[0].arn : null
}

# ========================================
# IAM Policy Outputs
# ========================================

output "dynamodb_kms_policy_arn" {
  description = "The ARN of the DynamoDB KMS access policy"
  value       = var.enable_dynamodb_key ? aws_iam_policy.dynamodb_kms[0].arn : null
}

output "lambda_kms_policy_arn" {
  description = "The ARN of the Lambda KMS access policy"
  value       = var.enable_lambda_key ? aws_iam_policy.lambda_kms[0].arn : null
}

output "s3_kms_policy_arn" {
  description = "The ARN of the S3 KMS access policy"
  value       = var.enable_s3_key ? aws_iam_policy.s3_kms[0].arn : null
}

# ========================================
# Multi-Region Key Outputs
# Note: These are disabled until multi-region support is properly configured
# ========================================

output "dynamodb_replica_key_ids" {
  description = "Map of replica region to DynamoDB KMS key IDs (disabled - requires provider configuration)"
  value       = {}
}

output "dynamodb_replica_key_arns" {
  description = "Map of replica region to DynamoDB KMS key ARNs (disabled - requires provider configuration)"
  value       = {}
}

output "dynamodb_replica_key_aliases" {
  description = "Map of replica region to DynamoDB KMS key alias names (disabled - requires provider configuration)"
  value       = {}
}

# ========================================
# Consolidated Outputs for Easy Reference
# ========================================

output "all_key_ids" {
  description = "Map of service name to KMS key ID"
  value = {
    dynamodb        = var.enable_dynamodb_key ? aws_kms_key.dynamodb[0].key_id : null
    s3              = var.enable_s3_key ? aws_kms_key.s3[0].key_id : null
    lambda          = var.enable_lambda_key ? aws_kms_key.lambda[0].key_id : null
    secrets_manager = var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].key_id : null
    parameter_store = var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].key_id : null
    kinesis         = var.enable_kinesis_key ? aws_kms_key.kinesis[0].key_id : null
    logs            = var.enable_logs_key ? aws_kms_key.logs[0].key_id : null
  }
}

output "all_key_arns" {
  description = "Map of service name to KMS key ARN"
  value = {
    dynamodb        = var.enable_dynamodb_key ? aws_kms_key.dynamodb[0].arn : null
    s3              = var.enable_s3_key ? aws_kms_key.s3[0].arn : null
    lambda          = var.enable_lambda_key ? aws_kms_key.lambda[0].arn : null
    secrets_manager = var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].arn : null
    parameter_store = var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].arn : null
    kinesis         = var.enable_kinesis_key ? aws_kms_key.kinesis[0].arn : null
    logs            = var.enable_logs_key ? aws_kms_key.logs[0].arn : null
  }
}

output "all_key_aliases" {
  description = "Map of service name to KMS key alias"
  value = {
    dynamodb        = var.enable_dynamodb_key ? aws_kms_alias.dynamodb[0].name : null
    s3              = var.enable_s3_key ? aws_kms_alias.s3[0].name : null
    lambda          = var.enable_lambda_key ? aws_kms_alias.lambda[0].name : null
    secrets_manager = var.enable_secrets_manager_key ? aws_kms_alias.secrets_manager[0].name : null
    parameter_store = var.enable_parameter_store_key ? aws_kms_alias.parameter_store[0].name : null
    kinesis         = var.enable_kinesis_key ? aws_kms_alias.kinesis[0].name : null
    logs            = var.enable_logs_key ? aws_kms_alias.logs[0].name : null
  }
}

output "all_key_alias_arns" {
  description = "Map of service name to KMS key alias ARN"
  value = {
    dynamodb        = var.enable_dynamodb_key ? aws_kms_alias.dynamodb[0].arn : null
    s3              = var.enable_s3_key ? aws_kms_alias.s3[0].arn : null
    lambda          = var.enable_lambda_key ? aws_kms_alias.lambda[0].arn : null
    secrets_manager = var.enable_secrets_manager_key ? aws_kms_alias.secrets_manager[0].arn : null
    parameter_store = var.enable_parameter_store_key ? aws_kms_alias.parameter_store[0].arn : null
    kinesis         = var.enable_kinesis_key ? aws_kms_alias.kinesis[0].arn : null
    logs            = var.enable_logs_key ? aws_kms_alias.logs[0].arn : null
  }
}

# ========================================
# Utility Outputs
# ========================================

output "key_rotation_status" {
  description = "Status of key rotation for all enabled keys"
  value = {
    dynamodb        = var.enable_dynamodb_key ? aws_kms_key.dynamodb[0].enable_key_rotation : null
    s3              = var.enable_s3_key ? aws_kms_key.s3[0].enable_key_rotation : null
    lambda          = var.enable_lambda_key ? aws_kms_key.lambda[0].enable_key_rotation : null
    secrets_manager = var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].enable_key_rotation : null
    parameter_store = var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].enable_key_rotation : null
    kinesis         = var.enable_kinesis_key ? aws_kms_key.kinesis[0].enable_key_rotation : null
    logs            = var.enable_logs_key ? aws_kms_key.logs[0].enable_key_rotation : null
  }
}

output "enabled_services" {
  description = "List of services with KMS keys enabled"
  value = compact([
    var.enable_dynamodb_key ? "dynamodb" : null,
    var.enable_s3_key ? "s3" : null,
    var.enable_lambda_key ? "lambda" : null,
    var.enable_secrets_manager_key ? "secrets_manager" : null,
    var.enable_parameter_store_key ? "parameter_store" : null,
    var.enable_kinesis_key ? "kinesis" : null,
    var.enable_logs_key ? "logs" : null,
  ])
}

output "kms_summary" {
  description = "Summary of KMS configuration"
  value = {
    environment          = var.environment
    key_rotation_enabled = var.enable_key_rotation
    deletion_window_days = var.key_deletion_window
    multi_region_enabled = var.enable_multi_region
    replica_regions      = var.replica_regions
    enabled_services = compact([
      var.enable_dynamodb_key ? "dynamodb" : null,
      var.enable_s3_key ? "s3" : null,
      var.enable_lambda_key ? "lambda" : null,
      var.enable_secrets_manager_key ? "secrets_manager" : null,
      var.enable_parameter_store_key ? "parameter_store" : null,
      var.enable_kinesis_key ? "kinesis" : null,
      var.enable_logs_key ? "logs" : null,
    ])
  }
}