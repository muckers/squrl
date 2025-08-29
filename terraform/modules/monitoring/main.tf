# Core monitoring resources for Squrl URL shortener service

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

# SNS topic for alarm notifications
resource "aws_sns_topic" "alerts" {
  count = var.alarm_sns_topic_arn == null ? 1 : 0
  name  = "${var.name_prefix}${var.service_name}-alerts-${var.environment}${var.name_suffix}"

  tags = merge(var.tags, {
    Name        = "${var.service_name}-alerts-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "monitoring-alerts"
  })
}

# SNS topic policy to allow CloudWatch to publish
resource "aws_sns_topic_policy" "alerts" {
  count = var.alarm_sns_topic_arn == null ? 1 : 0
  arn   = aws_sns_topic.alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarmsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "SNS:Publish",
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission"
        ]
        Resource = aws_sns_topic.alerts[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscriptions for alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alarm_sns_topic_arn == null ? length(var.alarm_email_endpoints) : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

# X-Ray tracing configuration
resource "aws_xray_sampling_rule" "squrl_sampling" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.service_name}-${var.environment}-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = var.service_name
  resource_arn   = "*"

  tags = merge(var.tags, {
    Name        = "${var.service_name}-xray-sampling-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

# Custom CloudWatch metrics namespace
resource "aws_cloudwatch_composite_alarm" "service_health" {
  count = var.enable_alarms ? 1 : 0

  alarm_name        = "${var.service_name}-service-health-${var.environment}"
  alarm_description = "Composite alarm tracking overall service health for ${var.service_name}"

  actions_enabled = true
  alarm_actions = [
    var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
  ]
  ok_actions = [
    var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
  ]

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.api_gateway_high_error_rate[0].alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.lambda_high_error_rate[0].alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.high_latency[0].alarm_name})"

  depends_on = [
    aws_cloudwatch_metric_alarm.api_gateway_high_error_rate,
    aws_cloudwatch_metric_alarm.lambda_high_error_rate,
    aws_cloudwatch_metric_alarm.high_latency
  ]

  tags = merge(var.tags, {
    Name        = "${var.service_name}-service-health-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "composite"
  })
}

# Cost anomaly detection - disabled for compatibility
# Note: aws_ce_anomaly_detector might not be available in all provider versions
# resource "aws_ce_anomaly_detector" "service_costs" {
#   count = var.enable_cost_anomaly_detection ? 1 : 0
#   
#   name         = "${var.service_name}-cost-anomaly-${var.environment}"
#   monitor_type = "CUSTOM"
#   
#   specification = jsonencode({
#     Dimension = {
#       Key           = "SERVICE"
#       Values        = ["Amazon API Gateway", "AWS Lambda", "Amazon DynamoDB", "Amazon CloudFront", "Amazon Kinesis"]
#       MatchOptions  = ["EQUALS"]
#     }
#     Tags = {
#       Key           = "Service"
#       Values        = [var.service_name]
#       MatchOptions  = ["EQUALS"]
#     }
#   })
# 
#   tags = merge(var.tags, {
#     Name        = "${var.service_name}-cost-anomaly-${var.environment}"
#     Environment = var.environment
#     Service     = var.service_name
#   })
# }
# 
# resource "aws_ce_anomaly_subscription" "service_cost_alerts" {
#   count = var.enable_cost_anomaly_detection && length(var.alarm_email_endpoints) > 0 ? 1 : 0
#   
#   name      = "${var.service_name}-cost-anomaly-alerts-${var.environment}"
#   frequency = "DAILY"
#   
#   monitor_arn_list = [
#     aws_ce_anomaly_detector.service_costs[0].arn
#   ]
#   
#   subscriber {
#     type    = "EMAIL"
#     address = var.alarm_email_endpoints[0]  # Use first email for cost alerts
#   }
#   
#   threshold_expression {
#     and {
#       dimension {
#         key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
#         values        = ["10"]  # Alert on anomalies over $10
#         match_options = ["GREATER_THAN_OR_EQUAL"]
#       }
#     }
#   }
# 
#   tags = merge(var.tags, {
#     Name        = "${var.service_name}-cost-anomaly-alerts-${var.environment}"
#     Environment = var.environment
#     Service     = var.service_name
#   })
# }

# CloudWatch Event Rules for automated responses
resource "aws_cloudwatch_event_rule" "high_error_rate" {
  count = var.enable_alarms ? 1 : 0

  name        = "${var.service_name}-high-error-rate-${var.environment}"
  description = "Triggers when API error rate is high"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [aws_cloudwatch_metric_alarm.api_gateway_high_error_rate[0].alarm_name]
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-high-error-rate-rule-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

# CloudWatch Event Target for automated logging
resource "aws_cloudwatch_event_target" "error_rate_logger" {
  count = var.enable_alarms ? 1 : 0

  rule      = aws_cloudwatch_event_rule.high_error_rate[0].name
  target_id = "ErrorRateLogger"
  arn       = aws_cloudwatch_log_group.alert_processing.arn

  input_transformer {
    input_paths = {
      alarm_name = "$.detail.alarmName"
      state      = "$.detail.state.value"
      reason     = "$.detail.state.reason"
      timestamp  = "$.detail.state.timestamp"
    }

    input_template = jsonencode({
      timestamp   = "<timestamp>"
      alarm_name  = "<alarm_name>"
      state       = "<state>"
      reason      = "<reason>"
      environment = var.environment
      service     = var.service_name
      alert_type  = "high_error_rate"
      severity    = "HIGH"
    })
  }
}

# IAM role for CloudWatch Events to write to logs
resource "aws_iam_role" "cloudwatch_events_log_role" {
  count = var.enable_alarms ? 1 : 0
  name  = "${var.service_name}-cloudwatch-events-log-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-cloudwatch-events-log-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy" "cloudwatch_events_log_policy" {
  count = var.enable_alarms ? 1 : 0
  name  = "CloudWatchEventsLogPolicy"
  role  = aws_iam_role.cloudwatch_events_log_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "${aws_cloudwatch_log_group.alert_processing.arn}:*"
      }
    ]
  })
}

# Lambda function for privacy-compliant aggregate analytics processing
resource "aws_lambda_function" "analytics_processor" {
  count = var.enable_custom_metrics ? 1 : 0

  function_name = "${var.service_name}-analytics-processor-${var.environment}"
  role          = aws_iam_role.analytics_processor_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  filename         = "${path.module}/analytics_processor.zip"
  source_code_hash = data.archive_file.analytics_processor_zip[0].output_base64sha256

  environment {
    variables = {
      LOG_GROUP_NAME      = aws_cloudwatch_log_group.service_analytics[0].name
      ENVIRONMENT         = var.environment
      SERVICE_NAME        = var.service_name
      ALERT_SNS_TOPIC_ARN = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-analytics-processor-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Function    = "analytics-processing"
  })
}

# Zip file for analytics processor Lambda
data "archive_file" "analytics_processor_zip" {
  count = var.enable_custom_metrics ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/analytics_processor.zip"

  source {
    content = templatefile("${path.module}/templates/privacy_compliant_analytics.py", {
      service_name = var.service_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for analytics processor Lambda
resource "aws_iam_role" "analytics_processor_role" {
  count = var.enable_custom_metrics ? 1 : 0
  name  = "${var.service_name}-analytics-processor-role-${var.environment}"

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
    Name        = "${var.service_name}-analytics-processor-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy_attachment" "analytics_processor_basic" {
  count      = var.enable_custom_metrics ? 1 : 0
  role       = aws_iam_role.analytics_processor_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "analytics_processor_custom" {
  count = var.enable_custom_metrics ? 1 : 0
  name  = "AnalyticsProcessorCustomPolicy"
  role  = aws_iam_role.analytics_processor_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
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

# CloudWatch Event Rule to trigger analytics processor
resource "aws_cloudwatch_event_rule" "analytics_processor_schedule" {
  count = var.enable_custom_metrics ? 1 : 0

  name                = "${var.service_name}-analytics-processor-schedule-${var.environment}"
  description         = "Triggers anonymous analytics processor every 15 minutes"
  schedule_expression = "rate(15 minutes)"

  tags = merge(var.tags, {
    Name        = "${var.service_name}-analytics-processor-schedule-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_cloudwatch_event_target" "analytics_processor" {
  count     = var.enable_custom_metrics ? 1 : 0
  rule      = aws_cloudwatch_event_rule.analytics_processor_schedule[0].name
  target_id = "AnalyticsProcessorTarget"
  arn       = aws_lambda_function.analytics_processor[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_analytics" {
  count         = var.enable_custom_metrics ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_processor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.analytics_processor_schedule[0].arn
}