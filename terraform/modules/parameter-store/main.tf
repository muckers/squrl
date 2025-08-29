terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source to get current AWS region
data "aws_region" "current" {}

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

# Local variables for parameter path construction
locals {
  # Construct hierarchical parameter paths: /{environment}/{app_name}/{parameter_name}
  parameter_paths = {
    for param_name, param_config in var.parameters : param_name => {
      name        = param_name
      path        = "/${var.environment}/${var.app_name}/${param_name}"
      value       = param_config.value
      type        = param_config.type
      description = param_config.description
      tier        = param_config.tier
      key_id      = param_config.key_id
      tags        = param_config.tags
    }
  }

  # Group parameters by type for easier management
  string_parameters = {
    for k, v in local.parameter_paths : k => v if v.type == "String"
  }

  string_list_parameters = {
    for k, v in local.parameter_paths : k => v if v.type == "StringList"
  }

  secure_string_parameters = {
    for k, v in local.parameter_paths : k => v if v.type == "SecureString"
  }

  # Common tags to apply to all resources
  common_tags = merge(var.tags, {
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "terraform"
  })
}

# String parameters (non-sensitive configuration values)
resource "aws_ssm_parameter" "string_parameters" {
  for_each = local.string_parameters

  name        = each.value.path
  type        = each.value.type
  value       = each.value.value
  description = each.value.description
  tier        = each.value.tier

  tags = merge(local.common_tags, each.value.tags)
}

# StringList parameters (comma-separated lists)
resource "aws_ssm_parameter" "string_list_parameters" {
  for_each = local.string_list_parameters

  name        = each.value.path
  type        = each.value.type
  value       = each.value.value
  description = each.value.description
  tier        = each.value.tier

  tags = merge(local.common_tags, each.value.tags)
}

# SecureString parameters (encrypted sensitive values)
resource "aws_ssm_parameter" "secure_string_parameters" {
  for_each = local.secure_string_parameters

  name        = each.value.path
  type        = each.value.type
  value       = each.value.value
  description = each.value.description
  tier        = each.value.tier
  key_id      = each.value.key_id != null ? each.value.key_id : var.default_kms_key_id

  tags = merge(local.common_tags, each.value.tags)
}

# IAM policy document for reading parameters
data "aws_iam_policy_document" "parameter_read_policy" {
  statement {
    sid    = "AllowSSMParameterRead"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]

    resources = [
      for param_name, param_config in local.parameter_paths :
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${param_config.path}"
    ]
  }

  # Additional permissions for SecureString parameters
  dynamic "statement" {
    for_each = length(local.secure_string_parameters) > 0 ? [1] : []

    content {
      sid    = "AllowKMSDecryptForSecureStrings"
      effect = "Allow"

      actions = [
        "kms:Decrypt"
      ]

      resources = [
        var.default_kms_key_id != null ? var.default_kms_key_id : "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"
      ]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["ssm.${data.aws_region.current.name}.amazonaws.com"]
      }
    }
  }
}

# IAM policy document for writing parameters (for CI/CD or admin operations)
data "aws_iam_policy_document" "parameter_write_policy" {
  statement {
    sid    = "AllowSSMParameterWrite"
    effect = "Allow"

    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]

    resources = [
      for param_name, param_config in local.parameter_paths :
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${param_config.path}"
    ]
  }

  # Additional permissions for SecureString parameters
  dynamic "statement" {
    for_each = length(local.secure_string_parameters) > 0 ? [1] : []

    content {
      sid    = "AllowKMSForSecureStrings"
      effect = "Allow"

      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]

      resources = [
        var.default_kms_key_id != null ? var.default_kms_key_id : "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"
      ]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["ssm.${data.aws_region.current.name}.amazonaws.com"]
      }
    }
  }
}

# IAM policy for reading parameters (for Lambda functions and applications)
resource "aws_iam_policy" "parameter_read_policy" {
  name_prefix = "${var.app_name}-${var.environment}-ssm-read-"
  description = "Policy allowing read access to SSM parameters for ${var.app_name} in ${var.environment}"

  policy = data.aws_iam_policy_document.parameter_read_policy.json

  tags = local.common_tags
}

# IAM policy for writing parameters (for CI/CD or admin operations)
resource "aws_iam_policy" "parameter_write_policy" {
  count = var.create_write_policy ? 1 : 0

  name_prefix = "${var.app_name}-${var.environment}-ssm-write-"
  description = "Policy allowing write access to SSM parameters for ${var.app_name} in ${var.environment}"

  policy = data.aws_iam_policy_document.parameter_write_policy.json

  tags = local.common_tags
}

# Optional parameter group for organizing parameters
resource "aws_resourcegroups_group" "parameter_group" {
  count = var.create_parameter_group ? 1 : 0

  name        = "${var.app_name}-${var.environment}-parameters"
  description = "Parameter group for ${var.app_name} in ${var.environment} environment"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::SSM::Parameter"]
      TagFilters = [
        {
          Key    = "Environment"
          Values = [var.environment]
        },
        {
          Key    = "AppName"
          Values = [var.app_name]
        }
      ]
    })
  }

  tags = local.common_tags
}

# CloudWatch Log Group for parameter access logging (optional)
resource "aws_cloudwatch_log_group" "parameter_access_logs" {
  count = var.enable_parameter_logging ? 1 : 0

  name              = "/aws/ssm/parameter-access/${var.app_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# Example of creating a parameter hierarchy for common patterns
# This demonstrates how to structure parameters for different components

# Create a base configuration parameter that other components can reference
resource "aws_ssm_parameter" "base_config" {
  count = var.create_base_config ? 1 : 0

  name = "/${var.environment}/${var.app_name}/config/base"
  type = "String"
  value = jsonencode({
    app_name    = var.app_name
    environment = var.environment
    region      = data.aws_region.current.name
    created_at  = timestamp()
  })
  description = "Base configuration for ${var.app_name} in ${var.environment}"
  tier        = var.default_parameter_tier

  tags = local.common_tags
}

# Create environment-specific feature flags
resource "aws_ssm_parameter" "feature_flags" {
  for_each = var.feature_flags

  name        = "/${var.environment}/${var.app_name}/features/${each.key}"
  type        = "String"
  value       = tostring(each.value)
  description = "Feature flag: ${each.key}"
  tier        = var.default_parameter_tier

  tags = merge(local.common_tags, {
    ParameterType = "FeatureFlag"
  })
}