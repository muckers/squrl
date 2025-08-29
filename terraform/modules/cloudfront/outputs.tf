# CloudFront Distribution outputs
output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID for Route53 alias records"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "status" {
  description = "CloudFront distribution status"
  value       = aws_cloudfront_distribution.main.status
}

output "etag" {
  description = "CloudFront distribution configuration ETag"
  value       = aws_cloudfront_distribution.main.etag
}

# WAF outputs
output "web_acl_id" {
  description = "WAF Web ACL ID (if WAF is enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN (if WAF is enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "web_acl_name" {
  description = "WAF Web ACL name (if WAF is enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].name : null
}

# Cache Policy outputs
output "cache_policy_ids" {
  description = "Map of cache policy names to IDs"
  value = {
    api_default = aws_cloudfront_cache_policy.api_default.id
    redirect    = aws_cloudfront_cache_policy.redirect.id
    no_cache    = aws_cloudfront_cache_policy.no_cache.id
    stats       = aws_cloudfront_cache_policy.stats.id
  }
}

output "origin_request_policy_ids" {
  description = "Map of origin request policy names to IDs"
  value = {
    api_default = aws_cloudfront_origin_request_policy.api_default.id
    redirect    = aws_cloudfront_origin_request_policy.redirect.id
  }
}

output "response_headers_policy_id" {
  description = "Response headers policy ID"
  value       = aws_cloudfront_response_headers_policy.security_headers.id
}

# Logging outputs
output "access_logs_bucket" {
  description = "S3 bucket for CloudFront access logs (if enabled)"
  value       = var.enable_real_time_logs ? aws_s3_bucket.cloudfront_logs[0].bucket : null
}

output "waf_log_group_name" {
  description = "CloudWatch log group name for WAF logs (if enabled)"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].name : null
}

output "waf_log_group_arn" {
  description = "CloudWatch log group ARN for WAF logs (if enabled)"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].arn : null
}

# Monitoring outputs
output "cloudwatch_alarm_names" {
  description = "Map of CloudWatch alarm names"
  value = var.enable_waf ? {
    blocked_requests = aws_cloudwatch_metric_alarm.waf_blocked_requests[0].alarm_name
    rate_limit       = aws_cloudwatch_metric_alarm.waf_rate_limit_triggered[0].alarm_name
  } : {}
}

# URL outputs for easy access
output "cloudfront_url" {
  description = "Full CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL (if custom domain is configured)"
  value       = var.custom_domain_name != null ? "https://${var.custom_domain_name}" : null
}

# Configuration summary for debugging
output "configuration_summary" {
  description = "Summary of key configuration settings"
  value = {
    environment                 = var.environment
    waf_enabled                 = var.enable_waf
    rate_limit_per_5min         = var.rate_limit_requests_per_5min
    create_rate_limit_per_5min  = var.create_rate_limit_requests_per_5min
    scanner_detection_threshold = var.scanner_detection_404_threshold
    geo_restrictions_enabled    = var.enable_geo_restrictions
    logging_enabled             = var.enable_waf_logging
    compression_enabled         = var.enable_compression
    http2_enabled               = var.http2_enabled
    ipv6_enabled                = var.ipv6_enabled
    price_class                 = var.price_class
  }
}