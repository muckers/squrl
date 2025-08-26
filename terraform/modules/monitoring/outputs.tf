# Monitoring Module Outputs

# === SNS TOPIC OUTPUTS ===
output "alerts_sns_topic_arn" {
  description = "ARN of the SNS topic for monitoring alerts"
  value       = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : (var.enable_alarms ? aws_sns_topic.alerts[0].arn : null)
}

output "alerts_sns_topic_name" {
  description = "Name of the SNS topic for monitoring alerts"
  value       = var.alarm_sns_topic_arn != null ? null : (var.enable_alarms ? aws_sns_topic.alerts[0].name : null)
}

# === LOG GROUP OUTPUTS ===
output "log_groups" {
  description = "Map of CloudWatch log groups created for monitoring"
  value = {
    monitoring           = aws_cloudwatch_log_group.monitoring.name
    custom_metrics      = var.enable_custom_metrics ? aws_cloudwatch_log_group.custom_metrics[0].name : null
    abuse_detection     = var.enable_abuse_detection ? aws_cloudwatch_log_group.abuse_detection[0].name : null
    cost_monitoring     = aws_cloudwatch_log_group.cost_monitoring.name
    alert_processing    = aws_cloudwatch_log_group.alert_processing.name
  }
}

output "log_group_arns" {
  description = "Map of CloudWatch log group ARNs"
  value = {
    monitoring           = aws_cloudwatch_log_group.monitoring.arn
    custom_metrics      = var.enable_custom_metrics ? aws_cloudwatch_log_group.custom_metrics[0].arn : null
    abuse_detection     = var.enable_abuse_detection ? aws_cloudwatch_log_group.abuse_detection[0].arn : null
    cost_monitoring     = aws_cloudwatch_log_group.cost_monitoring.arn
    alert_processing    = aws_cloudwatch_log_group.alert_processing.arn
  }
}

# === DASHBOARD OUTPUTS ===
output "dashboard_urls" {
  description = "URLs to access CloudWatch dashboards"
  value = var.enable_dashboards ? {
    api_performance   = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.api_performance[0].dashboard_name}"
    abuse_detection   = var.enable_abuse_detection ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.abuse_detection[0].dashboard_name}" : null
    cost_tracking     = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.cost_tracking[0].dashboard_name}"
    system_health     = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.system_health[0].dashboard_name}"
  } : {}
}

output "dashboard_names" {
  description = "Names of the CloudWatch dashboards"
  value = var.enable_dashboards ? {
    api_performance   = aws_cloudwatch_dashboard.api_performance[0].dashboard_name
    abuse_detection   = var.enable_abuse_detection ? aws_cloudwatch_dashboard.abuse_detection[0].dashboard_name : null
    cost_tracking     = aws_cloudwatch_dashboard.cost_tracking[0].dashboard_name
    system_health     = aws_cloudwatch_dashboard.system_health[0].dashboard_name
  } : {}
}

# === ALARM OUTPUTS ===
output "critical_alarms" {
  description = "List of critical CloudWatch alarms"
  value = var.enable_alarms ? [
    aws_cloudwatch_metric_alarm.api_gateway_server_errors[0].alarm_name,
    aws_cloudwatch_metric_alarm.lambda_high_error_rate[0].alarm_name,
    aws_cloudwatch_metric_alarm.dynamodb_errors[0].alarm_name
  ] : []
}

output "all_alarm_names" {
  description = "List of all CloudWatch alarm names"
  value = var.enable_alarms ? concat(
    [aws_cloudwatch_metric_alarm.api_gateway_high_error_rate[0].alarm_name],
    [aws_cloudwatch_metric_alarm.api_gateway_server_errors[0].alarm_name],
    [aws_cloudwatch_metric_alarm.high_latency[0].alarm_name],
    [aws_cloudwatch_metric_alarm.lambda_high_error_rate[0].alarm_name],
    aws_cloudwatch_metric_alarm.lambda_throttling[*].alarm_name,
    [aws_cloudwatch_metric_alarm.dynamodb_read_throttling[0].alarm_name],
    [aws_cloudwatch_metric_alarm.dynamodb_write_throttling[0].alarm_name],
    var.enable_abuse_detection ? [aws_cloudwatch_metric_alarm.abuse_high_request_volume[0].alarm_name] : []
  ) : []
}

output "composite_alarms" {
  description = "List of composite CloudWatch alarms"
  value = var.enable_alarms ? [
    aws_cloudwatch_composite_alarm.service_health[0].alarm_name
  ] : []
}

# === ABUSE DETECTION OUTPUTS ===
output "abuse_detection_resources" {
  description = "Resources created for abuse detection (if enabled)"
  value = var.enable_abuse_detection ? {
    lambda_functions = var.enable_custom_metrics ? {
      abuse_processor          = aws_lambda_function.abuse_processor[0].function_name
      realtime_abuse_detector  = aws_lambda_function.realtime_abuse_detector[0].function_name
      ip_reputation_checker    = aws_lambda_function.ip_reputation_checker[0].function_name
      abuse_response_handler   = aws_lambda_function.abuse_response_handler[0].function_name
    } : {}
    dynamodb_tables = {
      abuse_tracking      = aws_dynamodb_table.abuse_tracking[0].name
      ip_reputation_cache = aws_dynamodb_table.ip_reputation_cache[0].name
    }
    event_rules = var.enable_custom_metrics ? [
      aws_cloudwatch_event_rule.suspicious_activity[0].name,
      aws_cloudwatch_event_rule.abuse_alert_response[0].name
    ] : []
  } : null
}

# === X-RAY OUTPUTS ===
output "xray_sampling_rule" {
  description = "X-Ray sampling rule name (if enabled)"
  value       = var.enable_xray_tracing ? aws_xray_sampling_rule.squrl_sampling[0].rule_name : null
}

# === COST MONITORING OUTPUTS ===
output "cost_anomaly_detector" {
  description = "Cost anomaly detector details (if enabled) - currently disabled for compatibility"
  value = null
}

# === LOG INSIGHTS QUERIES ===
output "log_insights_queries" {
  description = "CloudWatch Logs Insights saved queries - currently disabled for compatibility"
  value = {
    error_analysis       = null
    performance_analysis = null
    abuse_pattern_analysis = null
    cost_analysis        = null
  }
}

# === METRIC FILTERS ===
output "metric_filters" {
  description = "CloudWatch metric filters created"
  value = {
    api_errors           = aws_cloudwatch_log_metric_filter.api_errors.name
    high_latency_requests = aws_cloudwatch_log_metric_filter.high_latency_requests.name
    suspicious_requests  = var.enable_abuse_detection ? aws_cloudwatch_log_metric_filter.suspicious_requests[0].name : null
    daily_cost          = aws_cloudwatch_log_metric_filter.daily_cost.name
    rapid_requests      = var.enable_abuse_detection ? aws_cloudwatch_log_metric_filter.rapid_requests[0].name : null
    bot_user_agents     = var.enable_abuse_detection ? aws_cloudwatch_log_metric_filter.bot_user_agents[0].name : null
    scanner_behavior    = var.enable_abuse_detection ? aws_cloudwatch_log_metric_filter.scanner_behavior[0].name : null
  }
}

# === KMS OUTPUTS ===
output "kms_key_id" {
  description = "KMS key ID used for log encryption"
  value       = aws_kms_key.logs.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for log encryption"
  value       = aws_kms_key.logs.arn
}

output "kms_alias" {
  description = "KMS key alias for logs"
  value       = aws_kms_alias.logs.name
}

# === NOTIFICATION CONFIGURATION ===
output "notification_config" {
  description = "Summary of notification configuration"
  value = {
    sns_topic_arn    = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : (var.enable_alarms ? aws_sns_topic.alerts[0].arn : null)
    email_endpoints  = var.alarm_email_endpoints
    alarms_enabled   = var.enable_alarms
    total_alarms     = var.enable_alarms ? length(concat(
      [aws_cloudwatch_metric_alarm.api_gateway_high_error_rate[0].alarm_name],
      [aws_cloudwatch_metric_alarm.api_gateway_server_errors[0].alarm_name],
      [aws_cloudwatch_metric_alarm.high_latency[0].alarm_name],
      [aws_cloudwatch_metric_alarm.lambda_high_error_rate[0].alarm_name],
      aws_cloudwatch_metric_alarm.lambda_throttling[*].alarm_name,
      [aws_cloudwatch_metric_alarm.dynamodb_read_throttling[0].alarm_name],
      [aws_cloudwatch_metric_alarm.dynamodb_write_throttling[0].alarm_name]
    )) : 0
  }
}

# === MONITORING CONFIGURATION SUMMARY ===
output "monitoring_config" {
  description = "Summary of monitoring configuration"
  value = {
    environment                = var.environment
    service_name              = var.service_name
    dashboards_enabled        = var.enable_dashboards
    alarms_enabled           = var.enable_alarms
    abuse_detection_enabled  = var.enable_abuse_detection
    xray_tracing_enabled     = var.enable_xray_tracing
    cost_anomaly_enabled     = var.enable_cost_anomaly_detection
    custom_metrics_enabled   = var.enable_custom_metrics
    log_retention_days       = var.log_retention_days
    
    thresholds = {
      error_rate_percentage     = var.error_rate_threshold
      latency_p99_ms           = var.latency_p99_threshold_ms
      monthly_cost_threshold   = var.environment == "dev" ? var.monthly_cost_threshold_dev : var.monthly_cost_threshold_prod
      abuse_requests_per_ip    = var.abuse_requests_per_ip_threshold
      abuse_404_rate_percent   = var.abuse_404_rate_threshold
    }
  }
}

# === OPERATIONAL OUTPUTS ===
output "runbook_links" {
  description = "Links to operational runbooks and documentation"
  value = {
    cloudwatch_console = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}"
    log_insights       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:logs-insights"
    cost_explorer      = "https://console.aws.amazon.com/cost-management/home#/cost-explorer"
    sns_topics         = "https://${var.aws_region}.console.aws.amazon.com/sns/v3/home?region=${var.aws_region}#/topics"
    lambda_functions   = "https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions"
  }
}

# === AUTOMATION OUTPUTS ===
output "automation_resources" {
  description = "Resources created for monitoring automation"
  value = {
    event_rules = var.enable_alarms ? [
      aws_cloudwatch_event_rule.high_error_rate[0].name
    ] : []
    
    lambda_functions = var.enable_abuse_detection && var.enable_custom_metrics ? {
      abuse_processor = aws_lambda_function.abuse_processor[0].function_name
    } : {}
    
    scheduled_tasks = var.enable_abuse_detection && var.enable_custom_metrics ? [
      aws_cloudwatch_event_rule.abuse_processor_schedule[0].name
    ] : []
  }
}

# === SECURITY OUTPUTS ===
output "security_monitoring" {
  description = "Security monitoring configuration"
  value = var.enable_abuse_detection ? {
    abuse_detection_enabled = true
    realtime_monitoring    = var.enable_custom_metrics
    automated_response     = var.enable_custom_metrics
    ip_reputation_checking = var.enable_custom_metrics
    waf_integration       = var.waf_web_acl_name != null
    
    detection_patterns = [
      "high_volume_requests",
      "scanner_behavior", 
      "bot_detection",
      "url_creation_spam"
    ]
    
    response_capabilities = var.enable_custom_metrics ? [
      "ip_blocking",
      "rate_limiting",
      "alert_notifications",
      "automated_investigation"
    ] : []
  } : {
    abuse_detection_enabled = false
    realtime_monitoring    = false
    automated_response     = false
    ip_reputation_checking = false
    waf_integration       = false
    
    detection_patterns = []
    response_capabilities = []
  }
}

# === TROUBLESHOOTING OUTPUTS ===
output "troubleshooting_info" {
  description = "Information for troubleshooting monitoring issues"
  value = {
    log_group_names = [
      aws_cloudwatch_log_group.monitoring.name,
      aws_cloudwatch_log_group.cost_monitoring.name,
      aws_cloudwatch_log_group.alert_processing.name
    ]
    
    key_metrics_namespaces = [
      "AWS/ApiGateway",
      "AWS/Lambda", 
      "AWS/DynamoDB",
      "AWS/CloudFront",
      "AWS/Kinesis",
      "${var.service_name}/${var.environment}",
      "${var.service_name}/${var.environment}/Security"
    ]
    
    common_troubleshooting_queries = {
      recent_errors = "fields @timestamp, @message | filter level = \"ERROR\" | sort @timestamp desc | limit 20"
      high_latency  = "fields @timestamp, duration | filter duration > 1000 | sort duration desc | limit 20" 
      abuse_patterns = "fields @timestamp, source_ip | stats count() by source_ip | sort count() desc | limit 20"
    }
  }
}