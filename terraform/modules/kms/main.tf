# Enhanced KMS encryption module for Squrl URL shortener service
# Provides dedicated KMS keys for different AWS services with proper access policies

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Common key policy statements
  base_key_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  }

  # Service principals for key access
  service_principals = {
    dynamodb        = "dynamodb.amazonaws.com"
    s3              = "s3.amazonaws.com"
    lambda          = "lambda.amazonaws.com"
    secrets_manager = "secretsmanager.amazonaws.com"
    ssm             = "ssm.amazonaws.com"
    kinesis         = "kinesis.amazonaws.com"
    logs            = "logs.amazonaws.com"
    events          = "events.amazonaws.com"
  }
}

# ========================================
# DynamoDB KMS Key
# ========================================

resource "aws_kms_key" "dynamodb" {
  count = var.enable_dynamodb_key ? 1 : 0

  description             = "KMS key for DynamoDB encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowDynamoDBAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.dynamodb
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}dynamodb-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "dynamodb"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count         = var.enable_dynamodb_key ? 1 : 0
  name          = "alias/${var.name_prefix}dynamodb-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

# ========================================
# S3 KMS Key
# ========================================

resource "aws_kms_key" "s3" {
  count = var.enable_s3_key ? 1 : 0

  description             = "KMS key for S3 encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.s3
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}s3-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "s3"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "s3" {
  count         = var.enable_s3_key ? 1 : 0
  name          = "alias/${var.name_prefix}s3-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.s3[0].key_id
}

# ========================================
# Lambda KMS Key
# ========================================

resource "aws_kms_key" "lambda" {
  count = var.enable_lambda_key ? 1 : 0

  description             = "KMS key for Lambda encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.lambda
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "lambda.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}lambda-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "lambda"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "lambda" {
  count         = var.enable_lambda_key ? 1 : 0
  name          = "alias/${var.name_prefix}lambda-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.lambda[0].key_id
}

# ========================================
# Secrets Manager KMS Key
# ========================================

resource "aws_kms_key" "secrets_manager" {
  count = var.enable_secrets_manager_key ? 1 : 0

  description             = "KMS key for Secrets Manager encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.secrets_manager
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}secrets-manager-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "secrets-manager"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "secrets_manager" {
  count         = var.enable_secrets_manager_key ? 1 : 0
  name          = "alias/${var.name_prefix}secrets-manager-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.secrets_manager[0].key_id
}

# ========================================
# Parameter Store (SSM) KMS Key
# ========================================

resource "aws_kms_key" "parameter_store" {
  count = var.enable_parameter_store_key ? 1 : 0

  description             = "KMS key for Parameter Store encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowParameterStoreAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.ssm
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}parameter-store-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "parameter-store"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "parameter_store" {
  count         = var.enable_parameter_store_key ? 1 : 0
  name          = "alias/${var.name_prefix}parameter-store-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.parameter_store[0].key_id
}

# ========================================
# Kinesis KMS Key
# ========================================

resource "aws_kms_key" "kinesis" {
  count = var.enable_kinesis_key ? 1 : 0

  description             = "KMS key for Kinesis encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowKinesisAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.kinesis
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "kinesis.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}kinesis-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "kinesis"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "kinesis" {
  count         = var.enable_kinesis_key ? 1 : 0
  name          = "alias/${var.name_prefix}kinesis-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.kinesis[0].key_id
}

# ========================================
# CloudWatch Logs KMS Key
# ========================================

resource "aws_kms_key" "logs" {
  count = var.enable_logs_key ? 1 : 0

  description             = "KMS key for CloudWatch Logs encryption in ${var.environment}"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode(merge(local.base_key_policy, {
    Statement = concat(local.base_key_policy.Statement, [
      {
        Sid    = "AllowCloudWatchLogsAccess"
        Effect = "Allow"
        Principal = {
          Service = local.service_principals.logs
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ])
  }))

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}logs-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "logs"
    Purpose     = "encryption"
  })
}

resource "aws_kms_alias" "logs" {
  count         = var.enable_logs_key ? 1 : 0
  name          = "alias/${var.name_prefix}logs-${var.environment}${var.name_suffix}"
  target_key_id = aws_kms_key.logs[0].key_id
}

# ========================================
# Multi-Region Key Replication
# Note: Multi-region keys require provider aliases to be configured
# in the calling module. This is commented out to avoid validation errors.
# Uncomment and configure providers when multi-region support is needed.
# ========================================

# Example multi-region configuration (requires provider setup in calling module):
# 
# resource "aws_kms_replica_key" "dynamodb" {
#   for_each = var.enable_multi_region && var.enable_dynamodb_key ? var.replica_regions : {}
# 
#   description             = "Replica of DynamoDB KMS key for ${var.environment} in ${each.key}"
#   deletion_window_in_days = var.key_deletion_window
#   primary_key_arn         = aws_kms_key.dynamodb[0].arn
# 
#   provider = aws.replica
# 
#   tags = merge(var.tags, {
#     Name        = "${var.name_prefix}dynamodb-${var.environment}-replica-${each.key}${var.name_suffix}"
#     Environment = var.environment
#     Service     = "dynamodb"
#     Purpose     = "encryption-replica"
#     Region      = each.key
#   })
# }
# 
# resource "aws_kms_alias" "dynamodb_replica" {
#   for_each = var.enable_multi_region && var.enable_dynamodb_key ? var.replica_regions : {}
# 
#   name          = "alias/${var.name_prefix}dynamodb-${var.environment}-replica-${each.key}${var.name_suffix}"
#   target_key_id = aws_kms_replica_key.dynamodb[each.key].key_id
# 
#   provider = aws.replica
# }

# ========================================
# IAM Policies for Service Access
# ========================================

# DynamoDB service policy
resource "aws_iam_policy" "dynamodb_kms" {
  count = var.enable_dynamodb_key ? 1 : 0

  name        = "${var.name_prefix}dynamodb-kms-${var.environment}${var.name_suffix}"
  description = "Policy for DynamoDB to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoDBKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.dynamodb[0].arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}dynamodb-kms-policy-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "dynamodb"
  })
}

# Lambda service policy
resource "aws_iam_policy" "lambda_kms" {
  count = var.enable_lambda_key ? 1 : 0

  name        = "${var.name_prefix}lambda-kms-${var.environment}${var.name_suffix}"
  description = "Policy for Lambda functions to use KMS keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.lambda[0].arn,
          var.enable_secrets_manager_key ? aws_kms_key.secrets_manager[0].arn : null,
          var.enable_parameter_store_key ? aws_kms_key.parameter_store[0].arn : null
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "lambda.${data.aws_region.current.name}.amazonaws.com",
              "secretsmanager.${data.aws_region.current.name}.amazonaws.com",
              "ssm.${data.aws_region.current.name}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}lambda-kms-policy-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "lambda"
  })
}

# S3 service policy
resource "aws_iam_policy" "s3_kms" {
  count = var.enable_s3_key ? 1 : 0

  name        = "${var.name_prefix}s3-kms-${var.environment}${var.name_suffix}"
  description = "Policy for S3 to use KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3[0].arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}s3-kms-policy-${var.environment}${var.name_suffix}"
    Environment = var.environment
    Service     = "s3"
  })
}