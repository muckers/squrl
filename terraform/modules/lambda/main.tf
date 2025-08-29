resource "aws_lambda_function" "function" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_exec.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"
  
  memory_size = var.memory_size
  timeout     = var.timeout
  
  # KMS key for environment variable encryption
  kms_key_arn = var.kms_key_arn
  
  environment {
    variables = merge({
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      RUST_LOG           = var.rust_log_level
      ENVIRONMENT        = var.environment
    }, var.additional_env_vars)
  }
  
  tracing_config {
    mode = "Active"
  }
  
  tags = var.tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}_role"
  
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
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.function_name}_dynamodb"
  role = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "kinesis_access" {
  count = var.kinesis_stream_arn != "" ? 1 : 0
  name  = "${var.function_name}_kinesis"
  role  = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = var.kinesis_stream_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "kinesis_read_access" {
  count = var.kinesis_read_permissions && var.kinesis_stream_arn != "" ? 1 : 0
  name  = "${var.function_name}_kinesis_read"
  role  = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards",
          "kinesis:ListStreams"
        ]
        Resource = var.kinesis_stream_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

# KMS permissions for Lambda if KMS key is provided
resource "aws_iam_role_policy" "lambda_kms_access" {
  count = var.kms_key_arn != null ? 1 : 0
  name  = "${var.function_name}_kms"
  role  = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Secrets Manager permissions for Lambda
resource "aws_iam_role_policy" "secrets_manager_access" {
  count = length(var.secrets_manager_arns) > 0 ? 1 : 0
  name  = "${var.function_name}_secrets_manager"
  role  = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_manager_arns
      },
      # KMS permissions for Secrets Manager if KMS key is used
      var.kms_key_arn != null ? {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      } : null
    ]
  })
}

# Data source for current AWS region
data "aws_region" "current" {}