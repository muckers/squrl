# WAF Web ACL Outputs
output "web_acl_arn" {
  description = "ARN of the WAF Web ACL for API Gateway"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "web_acl_id" {
  description = "ID of the WAF Web ACL for API Gateway"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "web_acl_name" {
  description = "Name of the WAF Web ACL for API Gateway"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].name : null
}

output "web_acl_capacity" {
  description = "Web ACL capacity units consumed"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].capacity : null
}

# Logging Outputs
output "waf_log_group_name" {
  description = "Name of the WAF CloudWatch log group"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].name : null
}

output "waf_log_group_arn" {
  description = "ARN of the WAF CloudWatch log group"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].arn : null
}

# CloudWatch Alarm Outputs
output "blocked_requests_alarm_name" {
  description = "Name of the blocked requests CloudWatch alarm"
  value       = var.enable_waf ? aws_cloudwatch_metric_alarm.waf_blocked_requests[0].alarm_name : null
}

output "rate_limit_alarm_name" {
  description = "Name of the rate limit CloudWatch alarm"
  value       = var.enable_waf ? aws_cloudwatch_metric_alarm.waf_rate_limit_triggered[0].alarm_name : null
}

output "create_rate_limit_alarm_name" {
  description = "Name of the create URL rate limit CloudWatch alarm"
  value       = var.enable_waf ? aws_cloudwatch_metric_alarm.waf_create_rate_limit_triggered[0].alarm_name : null
}

# Metrics and Monitoring
output "cloudwatch_metrics_config" {
  description = "CloudWatch metrics configuration for monitoring"
  value = var.enable_waf ? {
    namespace = "AWS/WAFV2"
    web_acl   = aws_wafv2_web_acl.main[0].name
    region    = data.aws_region.current.name
    rules = [
      {
        name        = "GlobalRateLimit"
        metric_name = "GlobalRateLimit"
        description = "Global rate limiting rule metrics"
      },
      {
        name        = "CreateURLRateLimit"
        metric_name = "CreateURLRateLimit"
        description = "Create URL rate limiting rule metrics"
      },
      {
        name        = "ScannerDetection"
        metric_name = "ScannerDetection"
        description = "Scanner detection rule metrics"
      },
      {
        name        = "RequestSizeRestriction"
        metric_name = "RequestSizeRestriction"
        description = "Request size restriction rule metrics"
      },
      {
        name        = "MalformedRequestBlocking"
        metric_name = "MalformedRequestBlocking"
        description = "Malformed request blocking rule metrics"
      }
    ]
  } : null
}

# Configuration Summary
output "waf_configuration" {
  description = "Summary of WAF configuration for reference"
  value = var.enable_waf ? {
    enabled                             = true
    scope                               = "REGIONAL"
    environment                         = var.environment
    rate_limit_requests_per_5min        = var.rate_limit_requests_per_5min
    create_rate_limit_requests_per_5min = var.create_rate_limit_requests_per_5min
    scanner_detection_404_threshold     = var.scanner_detection_404_threshold
    max_request_body_size_kb            = var.max_request_body_size_kb
    max_uri_length                      = var.max_uri_length
    geo_restrictions_enabled            = var.enable_geo_restrictions
    geo_restricted_countries            = var.geo_restricted_countries
    bot_control_enabled                 = var.enable_bot_control
    bot_control_inspection_level        = var.enable_bot_control ? var.bot_control_inspection_level : null
    logging_enabled                     = var.enable_waf_logging
    log_retention_days                  = var.enable_waf_logging ? var.waf_log_retention_days : null
    } : {
    enabled = false
  }
}

# Rule Priority Map for Reference
output "rule_priorities" {
  description = "Map of rule names to their priorities for reference"
  value = var.enable_waf ? {
    "GlobalRateLimit"                       = 10
    "CreateURLRateLimit"                    = 20
    "ScannerDetection"                      = 30
    "RequestSizeRestriction"                = 40
    "MalformedRequestBlocking"              = 50
    "GeographicRateLimit"                   = 60
    "AWSManagedRulesAmazonIpReputationList" = 70
    "AWSManagedRulesKnownBadInputsRuleSet"  = 80
    "AWSManagedRulesCommonRuleSet"          = 90
    "AWSManagedRulesBotControlRuleSet"      = 100
  } : null
}

# Association Status
output "api_gateway_association_status" {
  description = "Status of API Gateway WAF association"
  value = {
    enabled        = var.enable_waf && var.api_gateway_stage_arn != null
    stage_arn      = var.api_gateway_stage_arn
    association_id = var.enable_waf && var.api_gateway_stage_arn != null ? aws_wafv2_web_acl_association.api_gateway[0].id : null
  }
}