# Parameter ARNs
output "parameter_arns" {
  description = "Map of parameter names to their ARNs"
  value = merge(
    { for k, v in aws_ssm_parameter.string_parameters : k => v.arn },
    { for k, v in aws_ssm_parameter.string_list_parameters : k => v.arn },
    { for k, v in aws_ssm_parameter.secure_string_parameters : k => v.arn }
  )
}

output "string_parameter_arns" {
  description = "ARNs of String type parameters"
  value       = { for k, v in aws_ssm_parameter.string_parameters : k => v.arn }
}

output "string_list_parameter_arns" {
  description = "ARNs of StringList type parameters"
  value       = { for k, v in aws_ssm_parameter.string_list_parameters : k => v.arn }
}

output "secure_string_parameter_arns" {
  description = "ARNs of SecureString type parameters"
  value       = { for k, v in aws_ssm_parameter.secure_string_parameters : k => v.arn }
  sensitive   = true
}

# Parameter names with full paths
output "parameter_names" {
  description = "Map of parameter keys to their full SSM parameter names (paths)"
  value = merge(
    { for k, v in aws_ssm_parameter.string_parameters : k => v.name },
    { for k, v in aws_ssm_parameter.string_list_parameters : k => v.name },
    { for k, v in aws_ssm_parameter.secure_string_parameters : k => v.name }
  )
}

output "parameter_paths" {
  description = "Map of parameter keys to their hierarchical paths"
  value       = { for k, v in local.parameter_paths : k => v.path }
}

output "string_parameter_names" {
  description = "Names of String type parameters"
  value       = { for k, v in aws_ssm_parameter.string_parameters : k => v.name }
}

output "string_list_parameter_names" {
  description = "Names of StringList type parameters"
  value       = { for k, v in aws_ssm_parameter.string_list_parameters : k => v.name }
}

output "secure_string_parameter_names" {
  description = "Names of SecureString type parameters"
  value       = { for k, v in aws_ssm_parameter.secure_string_parameters : k => v.name }
  sensitive   = true
}

# Parameter values (only for non-secure parameters)
output "string_parameter_values" {
  description = "Values of String type parameters"
  value       = { for k, v in aws_ssm_parameter.string_parameters : k => v.value }
}

output "string_list_parameter_values" {
  description = "Values of StringList type parameters"
  value       = { for k, v in aws_ssm_parameter.string_list_parameters : k => v.value }
}

# Note: SecureString values are intentionally not output for security reasons

# IAM Policy ARNs
output "parameter_read_policy_arn" {
  description = "ARN of the IAM policy for reading parameters"
  value       = aws_iam_policy.parameter_read_policy.arn
}

output "parameter_write_policy_arn" {
  description = "ARN of the IAM policy for writing parameters (if created)"
  value       = var.create_write_policy ? aws_iam_policy.parameter_write_policy[0].arn : null
}

output "parameter_read_policy_name" {
  description = "Name of the IAM policy for reading parameters"
  value       = aws_iam_policy.parameter_read_policy.name
}

output "parameter_write_policy_name" {
  description = "Name of the IAM policy for writing parameters (if created)"
  value       = var.create_write_policy ? aws_iam_policy.parameter_write_policy[0].name : null
}

# Resource Group information
output "parameter_group_arn" {
  description = "ARN of the parameter resource group (if created)"
  value       = var.create_parameter_group ? aws_resourcegroups_group.parameter_group[0].arn : null
}

output "parameter_group_name" {
  description = "Name of the parameter resource group (if created)"
  value       = var.create_parameter_group ? aws_resourcegroups_group.parameter_group[0].name : null
}

# Base configuration
output "base_config_parameter_name" {
  description = "Name of the base configuration parameter (if created)"
  value       = var.create_base_config ? aws_ssm_parameter.base_config[0].name : null
}

output "base_config_parameter_arn" {
  description = "ARN of the base configuration parameter (if created)"
  value       = var.create_base_config ? aws_ssm_parameter.base_config[0].arn : null
}

# Feature flags
output "feature_flag_parameter_names" {
  description = "Map of feature flag names to their SSM parameter names"
  value       = { for k, v in aws_ssm_parameter.feature_flags : k => v.name }
}

output "feature_flag_parameter_arns" {
  description = "Map of feature flag names to their ARNs"
  value       = { for k, v in aws_ssm_parameter.feature_flags : k => v.arn }
}

output "feature_flag_values" {
  description = "Map of feature flag names to their values"
  value       = { for k, v in aws_ssm_parameter.feature_flags : k => v.value }
}

# Logging
output "parameter_access_log_group_name" {
  description = "Name of the CloudWatch log group for parameter access (if created)"
  value       = var.enable_parameter_logging ? aws_cloudwatch_log_group.parameter_access_logs[0].name : null
}

output "parameter_access_log_group_arn" {
  description = "ARN of the CloudWatch log group for parameter access (if created)"
  value       = var.enable_parameter_logging ? aws_cloudwatch_log_group.parameter_access_logs[0].arn : null
}

# Useful information for consumers
output "parameter_hierarchy_root" {
  description = "Root path for all parameters created by this module"
  value       = "/${var.environment}/${var.app_name}"
}

output "parameter_count" {
  description = "Total number of parameters created"
  value       = length(local.parameter_paths) + length(var.feature_flags) + (var.create_base_config ? 1 : 0)
}

output "parameter_count_by_type" {
  description = "Count of parameters by type"
  value = {
    string        = length(local.string_parameters)
    string_list   = length(local.string_list_parameters)
    secure_string = length(local.secure_string_parameters)
    feature_flags = length(var.feature_flags)
    base_config   = var.create_base_config ? 1 : 0
  }
}

# Environment and app information
output "environment" {
  description = "Environment name used in parameter paths"
  value       = var.environment
}

output "app_name" {
  description = "Application name used in parameter paths"
  value       = var.app_name
}

# KMS information
output "default_kms_key_id" {
  description = "Default KMS key ID used for SecureString parameters"
  value       = var.default_kms_key_id
  sensitive   = true
}

# For easier Lambda integration
output "lambda_environment_variables" {
  description = "Environment variables for Lambda functions to access parameters"
  value = {
    PARAMETER_STORE_PATH = "/${var.environment}/${var.app_name}"
    AWS_REGION           = data.aws_region.current.name
    ENVIRONMENT          = var.environment
    APP_NAME             = var.app_name
  }
}

# For CloudFormation/CDK integration
output "parameter_store_config" {
  description = "Configuration object for use in other infrastructure tools"
  value = {
    environment         = var.environment
    app_name            = var.app_name
    parameter_root_path = "/${var.environment}/${var.app_name}"
    read_policy_arn     = aws_iam_policy.parameter_read_policy.arn
    write_policy_arn    = var.create_write_policy ? aws_iam_policy.parameter_write_policy[0].arn : null
    kms_key_id          = var.default_kms_key_id
  }
}

# Summary output for debugging and verification
output "summary" {
  description = "Summary of created resources"
  value = {
    parameters_created = {
      total = length(local.parameter_paths) + length(var.feature_flags) + (var.create_base_config ? 1 : 0)
      by_type = {
        string        = length(local.string_parameters)
        string_list   = length(local.string_list_parameters)
        secure_string = length(local.secure_string_parameters)
      }
      feature_flags = length(var.feature_flags)
      base_config   = var.create_base_config
    }
    iam_policies = {
      read_policy_created  = true
      write_policy_created = var.create_write_policy
    }
    resource_group_created = var.create_parameter_group
    logging_enabled        = var.enable_parameter_logging
    parameter_root_path    = "/${var.environment}/${var.app_name}"
  }
}