# Outputs for AWS Secrets Manager Module

# Secret ARNs - useful for granting access to specific secrets
output "secret_arns" {
  description = "Map of secret names to their ARNs"
  value = {
    for key, secret in aws_secretsmanager_secret.secrets : key => secret.arn
  }
}

# Secret names - useful for referencing secrets in applications
output "secret_names" {
  description = "Map of secret keys to their full names in Secrets Manager"
  value = {
    for key, secret in aws_secretsmanager_secret.secrets : key => secret.name
  }
}

# Secret IDs - useful for referencing secrets in other Terraform resources
output "secret_ids" {
  description = "Map of secret keys to their IDs"
  value = {
    for key, secret in aws_secretsmanager_secret.secrets : key => secret.id
  }
}

# Lambda read policy ARN - for attaching to Lambda roles
output "lambda_secrets_read_policy_arn" {
  description = "ARN of the IAM policy that allows Lambda functions to read all secrets"
  value       = aws_iam_policy.lambda_secrets_read.arn
}

# Individual app policies ARNs - for more granular access control
output "app_secrets_read_policy_arns" {
  description = "Map of secret keys to their individual app read policy ARNs"
  value = {
    for key, policy in aws_iam_policy.app_secrets_read : key => policy.arn
  }
}

# Rotation Lambda function ARN (if created)
output "rotation_lambda_function_arn" {
  description = "ARN of the Lambda function used for secret rotation"
  value       = length(aws_lambda_function.rotation_function) > 0 ? aws_lambda_function.rotation_function[0].arn : null
}

# Rotation Lambda role ARN (if created)
output "rotation_lambda_role_arn" {
  description = "ARN of the IAM role used by the rotation Lambda function"
  value       = length(aws_iam_role.rotation_lambda_role) > 0 ? aws_iam_role.rotation_lambda_role[0].arn : null
}

# KMS key ARN used for encryption
output "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting secrets"
  value       = var.kms_key_arn
}

# Environment
output "environment" {
  description = "Environment name used for this secrets module"
  value       = var.environment
}

# Secret count
output "secret_count" {
  description = "Number of secrets created by this module"
  value       = length(aws_secretsmanager_secret.secrets)
}

# Secrets with rotation enabled
output "rotated_secrets" {
  description = "List of secret keys that have automatic rotation enabled"
  value = [
    for key, config in local.secrets_with_names : key
    if can(config.rotation_days)
  ]
}

# Full secret configuration for reference
output "secret_configuration" {
  description = "Full configuration of all secrets (excluding sensitive values)"
  value = {
    for key, config in local.secrets_with_names : key => {
      name             = config.secret_name
      description      = config.description
      rotation_enabled = can(config.rotation_days)
      rotation_days    = try(config.rotation_days, null)
      has_app_policy   = try(config.create_app_policy, false)
    }
  }
}

# Region information
output "aws_region" {
  description = "AWS region where the secrets are created"
  value       = data.aws_region.current.name
}

# Account ID
output "aws_account_id" {
  description = "AWS account ID where the secrets are created"
  value       = data.aws_caller_identity.current.account_id
}

# Secret ARN pattern for use in IAM policies
output "secret_arn_pattern" {
  description = "ARN pattern for all secrets created by this module (useful for IAM policies)"
  value       = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}-*"
}

# Tags applied to secrets
output "tags" {
  description = "Tags applied to all secrets"
  value       = var.tags
}