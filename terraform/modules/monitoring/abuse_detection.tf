# Privacy-Compliant Anonymous Pattern Detection Resources
# This module focuses on aggregate patterns without tracking individual users

# CloudWatch Event Rules for anonymous pattern detection
resource "aws_cloudwatch_event_rule" "anonymous_patterns" {
  count = var.enable_abuse_detection ? 1 : 0

  name        = "${var.service_name}-anonymous-patterns-${var.environment}"
  description = "Detects aggregate usage patterns without storing PII"

  event_pattern = jsonencode({
    source      = ["aws.apigateway"]
    detail-type = ["API Gateway Execution Logs"]
    detail = {
      status = ["404", "429", "500", "502", "503"]
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-anonymous-patterns-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "anonymous-pattern-detection"
  })
}

# Lambda function for anonymous aggregate pattern analysis
resource "aws_lambda_function" "anonymous_pattern_analyzer" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0

  function_name = "${var.service_name}-anonymous-pattern-analyzer-${var.environment}"
  role          = aws_iam_role.anonymous_pattern_analyzer_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = "${path.module}/anonymous_pattern_analyzer.zip"
  source_code_hash = data.archive_file.anonymous_pattern_analyzer_zip[0].output_base64sha256

  environment {
    variables = {
      CLOUDWATCH_LOG_GROUP = var.enable_abuse_detection ? aws_cloudwatch_log_group.service_analytics[0].name : ""
      SNS_TOPIC_ARN        = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      ENVIRONMENT          = var.environment
      SERVICE_NAME         = var.service_name
      ERROR_RATE_THRESHOLD = var.error_rate_threshold
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-anonymous-pattern-analyzer-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Function    = "anonymous-pattern-analysis"
  })
}

# Zip file for anonymous pattern analyzer
data "archive_file" "anonymous_pattern_analyzer_zip" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/anonymous_pattern_analyzer.zip"

  source {
    content = templatefile("${path.module}/templates/anonymous_pattern_analyzer.py", {
      service_name = var.service_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# DynamoDB table for anonymous aggregate metrics (no PII stored)
resource "aws_dynamodb_table" "anonymous_metrics" {
  count = var.enable_abuse_detection ? 1 : 0

  name         = "${var.service_name}-anonymous-metrics-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "metric_type"
  range_key    = "time_window"

  attribute {
    name = "metric_type"
    type = "S"
  }

  attribute {
    name = "time_window"
    type = "S"
  }

  attribute {
    name = "severity_level"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity_level"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-anonymous-metrics-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "anonymous-analytics"
  })
}

# IAM role for anonymous pattern analyzer
resource "aws_iam_role" "anonymous_pattern_analyzer_role" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "${var.service_name}-anonymous-pattern-analyzer-role-${var.environment}"

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

  tags = merge(var.tags, {
    Name        = "${var.service_name}-anonymous-pattern-analyzer-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy_attachment" "anonymous_pattern_analyzer_basic" {
  count      = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  role       = aws_iam_role.anonymous_pattern_analyzer_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "anonymous_pattern_analyzer_custom" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "AnonymousPatternAnalyzerCustomPolicy"
  role  = aws_iam_role.anonymous_pattern_analyzer_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.anonymous_metrics[0].arn,
          "${aws_dynamodb_table.anonymous_metrics[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.service_analytics[0].arn,
          "${aws_cloudwatch_log_group.service_analytics[0].arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "${var.service_name}/${var.environment}/Analytics"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      }
    ]
  })
}

# EventBridge target for anonymous pattern analysis (no PII collected)
resource "aws_cloudwatch_event_target" "anonymous_pattern_analyzer" {
  count     = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  rule      = aws_cloudwatch_event_rule.anonymous_patterns[0].name
  target_id = "AnonymousPatternAnalyzer"
  arn       = aws_lambda_function.anonymous_pattern_analyzer[0].arn

  input_transformer {
    input_paths = {
      status    = "$.detail.status"
      timestamp = "$.detail.timestamp"
      method    = "$.detail.httpMethod"
      resource  = "$.detail.resource"
    }

    input_template = jsonencode({
      # NOTE: NO IP ADDRESS OR USER-AGENT COLLECTED FOR PRIVACY
      status      = "<status>"
      timestamp   = "<timestamp>"
      method      = "<method>"
      resource    = "<resource>"
      environment = var.environment
      service     = var.service_name
    })
  }
}

resource "aws_lambda_permission" "allow_eventbridge_anonymous_patterns" {
  count         = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.anonymous_pattern_analyzer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.anonymous_patterns[0].arn
}

# PRIVACY COMPLIANCE: IP reputation checking removed
# Individual IP tracking violates user privacy
# Replaced with aggregate anonymous pattern detection

# PRIVACY COMPLIANCE: IP reputation caching removed
# Storing IP addresses with reputation data violates user privacy

# PRIVACY COMPLIANCE: IP reputation checking archive removed

# PRIVACY COMPLIANCE: IP reputation checker IAM role removed

# PRIVACY COMPLIANCE: IP reputation checker policy attachment removed

# PRIVACY COMPLIANCE: IP reputation checker custom policy removed

# Anonymous CloudWatch metrics for usage patterns (no PII)
resource "aws_cloudwatch_log_metric_filter" "anonymous_url_creation" {
  count = var.enable_abuse_detection ? 1 : 0

  name           = "${var.service_name}-anonymous-url-creation-${var.environment}"
  log_group_name = "/aws/apigateway/${var.api_gateway_name}"
  pattern        = "[timestamp, request_id, method=\"POST\", resource=\"/create\", status=\"2*\", latency]"

  metric_transformation {
    name          = "URLCreationRate"
    namespace     = "${var.service_name}/${var.environment}/Analytics"
    value         = "1"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Endpoint    = "create"
    }
  }
}

# PRIVACY COMPLIANCE: Bot detection based on user-agent removed
# User-agent strings can contain PII and are privacy-violating
# Replaced with anonymous HTTP status code analysis

resource "aws_cloudwatch_log_metric_filter" "anonymous_error_patterns" {
  count = var.enable_abuse_detection ? 1 : 0

  name           = "${var.service_name}-anonymous-error-patterns-${var.environment}"
  log_group_name = "/aws/apigateway/${var.api_gateway_name}"
  pattern        = "[timestamp, request_id, method, resource, status=\"404\", latency]"

  metric_transformation {
    name          = "NotFoundRequests"
    namespace     = "${var.service_name}/${var.environment}/Analytics"
    value         = "1"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Type        = "error-analysis"
    }
  }
}

# PRIVACY COMPLIANCE: Automated IP blocking system removed
# Individual IP blocking based on tracking violates privacy
# Use WAF rate limiting and other anonymous protection mechanisms

# PRIVACY COMPLIANCE: Abuse response handler archive removed

# PRIVACY COMPLIANCE: Abuse response handler IAM role removed

# PRIVACY COMPLIANCE: Abuse response handler policy attachment removed

# PRIVACY COMPLIANCE: Abuse response handler custom policy removed

# PRIVACY COMPLIANCE: Automated abuse alert response removed
# Individual tracking-based automated responses violate privacy

# PRIVACY COMPLIANCE: Abuse response handler event target removed

# PRIVACY COMPLIANCE: Abuse response handler lambda permission removed