# AWS Secrets Manager Module
# This module creates and manages AWS Secrets Manager secrets with rotation and IAM policies

locals {
  # Create normalized secret names with environment prefix
  secrets_with_names = {
    for key, config in var.secrets : key => merge(config, {
      secret_name = "${var.environment}-${key}"
    })
  }
}

# Create Secrets Manager secrets
resource "aws_secretsmanager_secret" "secrets" {
  for_each = local.secrets_with_names

  name        = each.value.secret_name
  description = each.value.description

  # Use provided KMS key or default encryption
  kms_key_id = var.kms_key_arn != null ? var.kms_key_arn : null

  # Configure automatic rotation if specified
  dynamic "rotation_rules" {
    for_each = can(each.value.rotation_days) ? [1] : []
    content {
      automatically_after_days = each.value.rotation_days
    }
  }

  # Force delete for non-production environments (optional)
  force_overwrite_replica_secret = var.environment != "prod" ? true : false

  # Deletion policy - immediate for dev/test, 30 days for prod
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Name        = each.value.secret_name
    Environment = var.environment
    SecretType  = each.key
  })
}

# Store initial secret values (if provided)
resource "aws_secretsmanager_secret_version" "secret_values" {
  for_each = {
    for key, config in local.secrets_with_names : key => config
    if can(config.secret_value) && config.secret_value != null
  }

  secret_id = aws_secretsmanager_secret.secrets[each.key].id

  # Support both string and JSON secret values
  secret_string = can(jsondecode(each.value.secret_value)) ? each.value.secret_value : jsonencode({
    value = each.value.secret_value
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Lambda rotation function (if rotation is enabled for any secret)
resource "aws_lambda_function" "rotation_function" {
  count = length([for k, v in local.secrets_with_names : k if can(v.rotation_days) && can(v.rotation_lambda_code)]) > 0 ? 1 : 0

  filename      = "rotation_function.zip"
  function_name = "${var.environment}-secrets-rotation"
  role          = aws_iam_role.rotation_lambda_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.environment}-secrets-rotation"
    Environment = var.environment
  })
}

# IAM role for Lambda rotation function
resource "aws_iam_role" "rotation_lambda_role" {
  count = length([for k, v in local.secrets_with_names : k if can(v.rotation_days) && can(v.rotation_lambda_code)]) > 0 ? 1 : 0

  name = "${var.environment}-secrets-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Lambda rotation function
resource "aws_iam_role_policy" "rotation_lambda_policy" {
  count = length([for k, v in local.secrets_with_names : k if can(v.rotation_days) && can(v.rotation_lambda_code)]) > 0 ? 1 : 0

  name = "${var.environment}-secrets-rotation-lambda-policy"
  role = aws_iam_role.rotation_lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [for secret in aws_secretsmanager_secret.secrets : secret.arn]
      }
    ]
  })
}

# Attach basic execution role to rotation Lambda
resource "aws_iam_role_policy_attachment" "rotation_lambda_basic" {
  count = length([for k, v in local.secrets_with_names : k if can(v.rotation_days) && can(v.rotation_lambda_code)]) > 0 ? 1 : 0

  role       = aws_iam_role.rotation_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Configure automatic rotation for secrets that require it
resource "aws_secretsmanager_secret_rotation" "secret_rotation" {
  for_each = {
    for key, config in local.secrets_with_names : key => config
    if can(config.rotation_days) && can(config.rotation_lambda_code)
  }

  secret_id           = aws_secretsmanager_secret.secrets[each.key].id
  rotation_lambda_arn = aws_lambda_function.rotation_function[0].arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }

  depends_on = [aws_lambda_function.rotation_function]
}

# IAM policy for Lambda functions to read secrets
resource "aws_iam_policy" "lambda_secrets_read" {
  name        = "${var.environment}-lambda-secrets-read"
  description = "Policy for Lambda functions to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [for secret in aws_secretsmanager_secret.secrets : secret.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn != null ? [var.kms_key_arn] : []
        Condition = var.kms_key_arn != null ? {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        } : null
      }
    ]
  })

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

# IAM policy for applications to read specific secrets (more restrictive)
resource "aws_iam_policy" "app_secrets_read" {
  for_each = {
    for key, config in local.secrets_with_names : key => config
    if can(config.create_app_policy) && config.create_app_policy == true
  }

  name        = "${var.environment}-app-${each.key}-secrets-read"
  description = "Policy for applications to read ${each.key} secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.secrets[each.key].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn != null ? [var.kms_key_arn] : []
        Condition = var.kms_key_arn != null ? {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        } : null
      }
    ]
  })

  tags = merge(var.tags, {
    Environment = var.environment
    SecretType  = each.key
  })
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}