# CloudWatch Log Groups for centralized log management

# Application-specific log groups
resource "aws_cloudwatch_log_group" "monitoring" {
  name              = "/aws/monitoring/${var.service_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name        = "${var.service_name}-monitoring-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    LogType     = "monitoring"
  })
}

# Custom metrics log group for structured application logs
resource "aws_cloudwatch_log_group" "custom_metrics" {
  count = var.enable_custom_metrics ? 1 : 0

  name              = "/aws/custom-metrics/${var.service_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name        = "${var.service_name}-custom-metrics-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    LogType     = "custom-metrics"
  })
}

# Service analytics log group (privacy-compliant)
resource "aws_cloudwatch_log_group" "service_analytics" {
  count = var.enable_abuse_detection ? 1 : 0

  name              = "/aws/service-analytics/${var.service_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name        = "${var.service_name}-service-analytics-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    LogType     = "service-analytics"
  })
}

# Cost monitoring log group
resource "aws_cloudwatch_log_group" "cost_monitoring" {
  name              = "/aws/cost-monitoring/${var.service_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name        = "${var.service_name}-cost-monitoring-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    LogType     = "cost-monitoring"
  })
}

# Alert processing log group
resource "aws_cloudwatch_log_group" "alert_processing" {
  name              = "/aws/alert-processing/${var.service_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name        = "${var.service_name}-alert-processing-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    LogType     = "alert-processing"
  })
}

# KMS key for log encryption
resource "aws_kms_key" "logs" {
  description             = "KMS key for ${var.service_name} ${var.environment} log encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = [
              "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/monitoring/${var.service_name}-${var.environment}",
              "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/custom-metrics/${var.service_name}-${var.environment}",
              "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/service-analytics/${var.service_name}-${var.environment}",
              "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cost-monitoring/${var.service_name}-${var.environment}",
              "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/alert-processing/${var.service_name}-${var.environment}"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-logs-kms-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "log-encryption"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.service_name}-logs-${var.environment}"
  target_key_id = aws_kms_key.logs.key_id
}

# Log streams for organized logging
resource "aws_cloudwatch_log_stream" "api_performance" {
  name           = "api-performance"
  log_group_name = aws_cloudwatch_log_group.monitoring.name
}

resource "aws_cloudwatch_log_stream" "error_tracking" {
  name           = "error-tracking"
  log_group_name = aws_cloudwatch_log_group.monitoring.name
}

resource "aws_cloudwatch_log_stream" "cost_tracking" {
  name           = "cost-tracking"
  log_group_name = aws_cloudwatch_log_group.cost_monitoring.name
}

resource "aws_cloudwatch_log_stream" "analytics_alerts" {
  count = var.enable_abuse_detection ? 1 : 0

  name           = "analytics-alerts"
  log_group_name = aws_cloudwatch_log_group.service_analytics[0].name
}

resource "aws_cloudwatch_log_stream" "anonymous_patterns" {
  count = var.enable_abuse_detection ? 1 : 0

  name           = "anonymous-patterns"
  log_group_name = aws_cloudwatch_log_group.service_analytics[0].name
}

# Log metric filters for automated parsing
resource "aws_cloudwatch_log_metric_filter" "api_errors" {
  name           = "${var.service_name}-api-errors-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.monitoring.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name          = "APIErrors"
    namespace     = "${var.service_name}/${var.environment}"
    value         = "1"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "high_latency_requests" {
  name           = "${var.service_name}-high-latency-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.monitoring.name
  pattern        = "[timestamp, request_id, level, duration > 1000, ...]"

  metric_transformation {
    name          = "HighLatencyRequests"
    namespace     = "${var.service_name}/${var.environment}"
    value         = "1"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "anonymous_log_error_patterns" {
  count = var.enable_abuse_detection ? 1 : 0

  name           = "${var.service_name}-anonymous-log-error-patterns-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.service_analytics[0].name
  # Privacy-compliant pattern - detects error patterns without storing PII
  pattern = "[timestamp, level=\"WARN\", pattern=\"*error*\", ...]"

  metric_transformation {
    name          = "AnonymousLogErrorPatterns"
    namespace     = "${var.service_name}/${var.environment}/Analytics"
    value         = "1"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Type        = "log-error-analysis"
    }
  }
}

# Cost tracking metric filter
resource "aws_cloudwatch_log_metric_filter" "daily_cost" {
  name           = "${var.service_name}-daily-cost-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.cost_monitoring.name
  pattern        = "[timestamp, service, cost_usd, ...]"

  metric_transformation {
    name          = "DailyCostUSD"
    namespace     = "${var.service_name}/${var.environment}/Cost"
    value         = "$cost_usd"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      Service     = var.service_name
    }
  }
}

# Data source for current AWS account
# AWS caller identity is defined in main.tf

# Log insights queries - disabled for compatibility
# Note: aws_logs_query_definition might not be available in all provider versions
# resource "aws_logs_query_definition" "error_analysis" {
#   name = "${var.service_name}-error-analysis-${var.environment}"
# 
#   log_group_names = [
#     aws_cloudwatch_log_group.monitoring.name
#   ]
# 
#   query_string = <<-QUERY
#     fields @timestamp, @message, level, error_type, error_message, request_id, function_name
#     | filter level = "ERROR"
#     | stats count() by error_type, function_name
#     | sort count() desc
#     | limit 20
#   QUERY
# }
# 
# resource "aws_logs_query_definition" "performance_analysis" {
#   name = "${var.service_name}-performance-analysis-${var.environment}"
# 
#   log_group_names = [
#     aws_cloudwatch_log_group.monitoring.name
#   ]
# 
#   query_string = <<-QUERY
#     fields @timestamp, @message, duration, function_name, memory_used, request_id
#     | filter duration > 100
#     | stats avg(duration), max(duration), min(duration), count() by function_name
#     | sort avg(duration) desc
#   QUERY
# }
# 
# resource "aws_logs_query_definition" "abuse_pattern_analysis" {
#   count = var.enable_abuse_detection ? 1 : 0
#   name  = "${var.service_name}-abuse-patterns-${var.environment}"
# 
#   log_group_names = [
#     aws_cloudwatch_log_group.abuse_detection[0].name
#   ]
# 
#   query_string = <<-QUERY
#     fields @timestamp, @message, source_ip, user_agent, endpoint, status_code
#     | stats count() as request_count by source_ip
#     | sort request_count desc
#     | limit 50
#   QUERY
# }
# 
# resource "aws_logs_query_definition" "cost_analysis" {
#   name = "${var.service_name}-cost-analysis-${var.environment}"
# 
#   log_group_names = [
#     aws_cloudwatch_log_group.cost_monitoring.name
#   ]
# 
#   query_string = <<-QUERY
#     fields @timestamp, @message, service_name, cost_usd, usage_quantity, usage_unit
#     | stats sum(cost_usd) as total_cost by service_name
#     | sort total_cost desc
#   QUERY
# }