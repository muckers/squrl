# CloudWatch Alarms for comprehensive monitoring and alerting

locals {
  sns_topic_arn = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : (var.enable_alarms ? aws_sns_topic.alerts[0].arn : "")
  cost_threshold_monthly = var.environment == "dev" ? var.monthly_cost_threshold_dev : var.monthly_cost_threshold_prod
  cost_threshold_daily = local.cost_threshold_monthly * var.daily_cost_threshold_multiplier / 30
}

# === API GATEWAY ALARMS ===

# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_high_error_rate" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-api-gateway-high-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4XX error rate"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-api-gateway-high-error-rate-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "error-rate"
    Severity    = "HIGH"
  })
}

# Server error alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_server_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-api-gateway-server-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors API Gateway 5XX server errors"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-api-gateway-server-errors-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "server-error"
    Severity    = "CRITICAL"
  })
}

# High latency alarm
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-api-gateway-high-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_p99_threshold_ms
  alarm_description   = "This metric monitors API Gateway P99 latency"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-api-gateway-high-latency-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "latency"
    Severity    = "MEDIUM"
  })
}

# API Gateway throttling alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_throttling" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-api-gateway-throttling-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ThrottleCount"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors API Gateway throttling events"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-api-gateway-throttling-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "throttling"
    Severity    = "HIGH"
  })
}

# === LAMBDA ALARMS ===

# Lambda error rate alarm for create-url function
resource "aws_cloudwatch_metric_alarm" "lambda_create_url_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-lambda-create-url-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors errors in the create-url Lambda function"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_names.create_url
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-create-url-errors-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "lambda-error"
    Function    = "create-url"
    Severity    = "HIGH"
  })
}

# Lambda error rate alarm for redirect function
resource "aws_cloudwatch_metric_alarm" "lambda_redirect_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-lambda-redirect-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"  # Higher threshold as redirect has more traffic
  alarm_description   = "This metric monitors errors in the redirect Lambda function"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_names.redirect
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-redirect-errors-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "lambda-error"
    Function    = "redirect"
    Severity    = "HIGH"
  })
}

# Lambda error rate alarm for analytics function
resource "aws_cloudwatch_metric_alarm" "lambda_analytics_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-lambda-analytics-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors errors in the analytics Lambda function"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_names.analytics
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-analytics-errors-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "lambda-error"
    Function    = "analytics"
    Severity    = "MEDIUM"
  })
}

# Composite Lambda error alarm
resource "aws_cloudwatch_metric_alarm" "lambda_high_error_rate" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-lambda-high-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  
  metric_query {
    id = "error_rate"
    expression = "(errors_create + errors_redirect + errors_analytics) / (invocations_create + invocations_redirect + invocations_analytics) * 100"
    label = "Lambda Error Rate %"
    return_data = true
  }
  
  metric_query {
    id = "errors_create"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.create_url
      }
    }
  }
  
  metric_query {
    id = "errors_redirect"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.redirect
      }
    }
  }
  
  metric_query {
    id = "errors_analytics"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.analytics
      }
    }
  }
  
  metric_query {
    id = "invocations_create"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.create_url
      }
    }
  }
  
  metric_query {
    id = "invocations_redirect"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.redirect
      }
    }
  }
  
  metric_query {
    id = "invocations_analytics"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_names.analytics
      }
    }
  }
  
  threshold          = var.error_rate_threshold
  alarm_description  = "This metric monitors overall Lambda error rate across all functions"
  alarm_actions      = [local.sns_topic_arn]
  ok_actions         = [local.sns_topic_arn]
  treat_missing_data = "notBreaching"

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-high-error-rate-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "composite-error-rate"
    Severity    = "HIGH"
  })
}

# Lambda throttling alarms
resource "aws_cloudwatch_metric_alarm" "lambda_throttling" {
  count = var.enable_alarms ? length(values(var.lambda_function_names)) : 0
  
  alarm_name          = "${var.service_name}-lambda-throttling-${element(keys(var.lambda_function_names), count.index)}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.lambda_throttle_threshold
  alarm_description   = "This metric monitors Lambda throttling for ${element(keys(var.lambda_function_names), count.index)} function"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = element(values(var.lambda_function_names), count.index)
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-throttling-${element(keys(var.lambda_function_names), count.index)}-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "lambda-throttling"
    Function    = element(keys(var.lambda_function_names), count.index)
    Severity    = "HIGH"
  })
}

# Lambda duration alarm (detecting performance degradation)
resource "aws_cloudwatch_metric_alarm" "lambda_high_duration" {
  count = var.enable_alarms ? length(values(var.lambda_function_names)) : 0
  
  alarm_name          = "${var.service_name}-lambda-high-duration-${element(keys(var.lambda_function_names), count.index)}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold = element(keys(var.lambda_function_names), count.index) == "create_url" ? "5000" : (
    element(keys(var.lambda_function_names), count.index) == "redirect" ? "2000" : "15000"
  )  # Different thresholds per function
  alarm_description   = "This metric monitors Lambda duration for ${element(keys(var.lambda_function_names), count.index)} function"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = element(values(var.lambda_function_names), count.index)
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-lambda-high-duration-${element(keys(var.lambda_function_names), count.index)}-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "lambda-duration"
    Function    = element(keys(var.lambda_function_names), count.index)
    Severity    = "MEDIUM"
  })
}

# === DYNAMODB ALARMS ===

# DynamoDB read throttling alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttling" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-dynamodb-read-throttling-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.dynamodb_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB read throttling events"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-dynamodb-read-throttling-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "dynamodb-throttling"
    Operation   = "read"
    Severity    = "HIGH"
  })
}

# DynamoDB write throttling alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttling" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-dynamodb-write-throttling-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.dynamodb_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB write throttling events"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-dynamodb-write-throttling-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "dynamodb-throttling"
    Operation   = "write"
    Severity    = "HIGH"
  })
}

# DynamoDB errors alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_errors" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-dynamodb-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "This metric monitors DynamoDB system errors"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-dynamodb-errors-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "dynamodb-error"
    Severity    = "HIGH"
  })
}

# === CLOUDFRONT ALARMS ===

# CloudFront cache hit rate alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_low_cache_hit_rate" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-cloudfront-low-cache-hit-rate-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cache_hit_rate_threshold
  alarm_description   = "This metric monitors CloudFront cache hit rate"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-cloudfront-low-cache-hit-rate-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "cache-performance"
    Severity    = "MEDIUM"
  })
}

# CloudFront origin latency alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_high_origin_latency" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-cloudfront-high-origin-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "OriginLatency"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.api_gateway_latency_threshold_ms
  alarm_description   = "This metric monitors CloudFront origin latency"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-cloudfront-high-origin-latency-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "origin-latency"
    Severity    = "MEDIUM"
  })
}

# === COST ALARMS ===

# Daily cost alarm
resource "aws_cloudwatch_metric_alarm" "high_daily_cost" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-high-daily-cost-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # 24 hours
  statistic           = "Maximum"
  threshold           = local.cost_threshold_daily
  alarm_description   = "This metric monitors daily AWS costs for ${var.service_name}"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-high-daily-cost-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "cost-threshold"
    Severity    = "HIGH"
  })
}

# === ABUSE DETECTION ALARMS ===

# High request volume alarm
resource "aws_cloudwatch_metric_alarm" "abuse_high_request_volume" {
  count = var.enable_alarms && var.enable_abuse_detection ? 1 : 0
  
  alarm_name          = "${var.service_name}-abuse-high-request-volume-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = var.abuse_requests_per_ip_threshold / 12  # 5-minute threshold
  alarm_description   = "This metric monitors for potential abuse - high request volume"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-high-request-volume-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "abuse-detection"
    Pattern     = "high-volume"
    Severity    = "MEDIUM"
  })
}

# High URL creation rate alarm
resource "aws_cloudwatch_metric_alarm" "abuse_high_url_creation" {
  count = var.enable_alarms && var.enable_abuse_detection ? 1 : 0
  
  alarm_name          = "${var.service_name}-abuse-high-url-creation-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = "3600"  # 1 hour
  statistic           = "Sum"
  threshold           = var.abuse_urls_per_ip_threshold * 5  # Allow some buffer
  alarm_description   = "This metric monitors for potential URL creation abuse"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName  = var.api_gateway_name
    Method   = "POST"
    Resource = "/create"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-high-url-creation-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "abuse-detection"
    Pattern     = "url-creation-spam"
    Severity    = "HIGH"
  })
}

# Custom abuse detection metrics alarms
resource "aws_cloudwatch_metric_alarm" "custom_abuse_detection" {
  count = var.enable_alarms && var.enable_abuse_detection && var.enable_custom_metrics ? 3 : 0
  
  alarm_name          = "${var.service_name}-custom-abuse-${local.abuse_pattern_names[count.index]}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AbuseDetections_${local.abuse_pattern_names[count.index]}"
  namespace           = "${var.service_name}/${var.environment}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Custom abuse detection: ${local.abuse_pattern_names[count.index]} pattern detected"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Environment = var.environment
    Service     = var.service_name
    PatternType = local.abuse_pattern_names[count.index]
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-custom-abuse-${local.abuse_pattern_names[count.index]}-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "custom-abuse-detection"
    Pattern     = local.abuse_pattern_names[count.index]
    Severity    = "HIGH"
  })
}

locals {
  abuse_pattern_names = ["high_volume", "scanner", "suspicious_patterns"]
}

# === WAF ALARMS ===

# WAF blocked requests alarm (if WAF is enabled)
resource "aws_cloudwatch_metric_alarm" "waf_high_blocked_requests" {
  count = var.enable_alarms && var.waf_web_acl_name != null ? 1 : 0
  
  alarm_name          = "${var.service_name}-waf-high-blocked-requests-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors high number of blocked requests by WAF"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_web_acl_name
    Region = "CloudFront"
    Rule   = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-waf-high-blocked-requests-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "waf-security"
    Severity    = "MEDIUM"
  })
}

# === KINESIS ALARMS ===

# Kinesis stream record processing alarm
resource "aws_cloudwatch_metric_alarm" "kinesis_processing_failure" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-kinesis-processing-failure-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PutRecords.FailedRecords"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Kinesis record processing failures"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    StreamName = var.kinesis_stream_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-kinesis-processing-failure-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "kinesis-processing"
    Severity    = "HIGH"
  })
}

# Kinesis iterator age alarm (backlog detection)
resource "aws_cloudwatch_metric_alarm" "kinesis_high_iterator_age" {
  count = var.enable_alarms ? 1 : 0
  
  alarm_name          = "${var.service_name}-kinesis-high-iterator-age-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "60000"  # 1 minute
  alarm_description   = "This metric monitors Kinesis stream processing backlog"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    StreamName = var.kinesis_stream_name
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-kinesis-high-iterator-age-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    AlarmType   = "kinesis-backlog"
    Severity    = "MEDIUM"
  })
}