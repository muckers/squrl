# API Gateway WAF Module

This Terraform module creates AWS WAF (Web Application Firewall) resources specifically designed for API Gateway protection. It provides comprehensive rate limiting, abuse protection, and security controls for the Squrl URL shortener API.

## Features

- **Regional WAF Web ACL** - Designed for API Gateway (REGIONAL scope)
- **Multi-layered Rate Limiting** - Global and endpoint-specific rate limits
- **Scanner Detection** - Identifies and blocks malicious scanning attempts
- **Request Size Controls** - Prevents oversized requests and DoS attacks
- **Malformed Request Blocking** - Blocks path traversal and injection attempts
- **Geographic Restrictions** - Optional country-based rate limiting
- **IP Reputation Lists** - AWS managed IP reputation rules
- **Bot Control** - Optional advanced bot detection (additional charges apply)
- **Comprehensive Logging** - CloudWatch integration with configurable retention
- **CloudWatch Alarms** - Automated monitoring and alerting

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Client        │────▶│   WAF Web ACL   │────▶│  API Gateway    │
│   Requests      │     │   (Regional)    │     │   REST API      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  CloudWatch     │
                        │  Logs & Alarms  │
                        └─────────────────┘
```

## WAF Rules Overview

| Priority | Rule Name | Purpose | Default Limit |
|----------|-----------|---------|---------------|
| 10 | GlobalRateLimit | Overall API rate limiting | 1000 req/5min |
| 20 | CreateURLRateLimit | Create endpoint protection | 500 req/5min |
| 30 | ScannerDetection | Block high 404 rates | 50 404s/5min |
| 40 | RequestSizeRestriction | Size constraints | 8KB body, 2KB URI |
| 50 | MalformedRequestBlocking | Block suspicious patterns | Always active |
| 60 | GeographicRateLimit | Country-based limits | Optional |
| 70 | IP Reputation List | AWS managed bad IPs | Always active |
| 80 | Known Bad Inputs | AWS managed malicious patterns | Always active |
| 90 | Common Rule Set | AWS managed OWASP protections | Always active |
| 100 | Bot Control | Advanced bot detection | Optional |

## Usage Examples

### Basic Usage

```hcl
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"

  environment             = "prod"
  api_gateway_stage_arn  = aws_api_gateway_stage.main.arn
  
  # Basic rate limiting
  rate_limit_requests_per_5min        = 2000
  create_rate_limit_requests_per_5min = 1000
  
  tags = {
    Project     = "squrl"
    Environment = "prod"
    Module      = "api-gateway-waf"
  }
}
```

### Advanced Configuration

```hcl
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"

  environment            = "prod"
  api_gateway_stage_arn = aws_api_gateway_stage.main.arn
  
  # Rate limiting configuration
  rate_limit_requests_per_5min         = 5000
  create_rate_limit_requests_per_5min  = 2000
  scanner_detection_404_threshold      = 100
  
  # Request size limits
  max_request_body_size_kb = 16
  max_uri_length          = 4096
  
  # Geographic restrictions
  enable_geo_restrictions    = true
  geo_restricted_countries   = ["CN", "RU", "KP"]
  geo_restricted_rate_limit  = 200
  
  # Bot control (additional charges apply)
  enable_bot_control            = true
  bot_control_inspection_level  = "TARGETED"
  
  # Logging and monitoring
  enable_waf_logging      = true
  waf_log_retention_days  = 90
  alarm_sns_topic_arn     = aws_sns_topic.alerts.arn
  
  # Custom thresholds
  blocked_requests_alarm_threshold     = 500
  rate_limit_alarm_threshold          = 50
  create_rate_limit_alarm_threshold   = 20
  
  tags = {
    Project     = "squrl"
    Environment = "prod"
    Module      = "api-gateway-waf"
    CostCenter  = "security"
  }
}
```

### Development Environment

```hcl
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"

  environment            = "dev"
  api_gateway_stage_arn = aws_api_gateway_stage.dev.arn
  
  # Relaxed limits for development
  rate_limit_requests_per_5min        = 10000
  create_rate_limit_requests_per_5min = 5000
  scanner_detection_404_threshold     = 200
  
  # Reduced logging retention
  waf_log_retention_days = 7
  
  # No geographic restrictions in dev
  enable_geo_restrictions = false
  
  # No bot control in dev (save costs)
  enable_bot_control = false
  
  tags = {
    Project     = "squrl"
    Environment = "dev"
    Module      = "api-gateway-waf"
  }
}
```

### WAF-Only (No Association)

```hcl
# Create WAF without immediate association
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"

  environment           = "staging"
  api_gateway_stage_arn = null  # No association
  
  rate_limit_requests_per_5min        = 3000
  create_rate_limit_requests_per_5min = 1500
  
  tags = {
    Project     = "squrl"
    Environment = "staging"
    Module      = "api-gateway-waf"
  }
}

# Associate later with existing stage
resource "aws_wafv2_web_acl_association" "staging_api" {
  resource_arn = aws_api_gateway_stage.staging.arn
  web_acl_arn  = module.api_gateway_waf.web_acl_arn
}
```

## Integration with API Gateway Module

Update your API Gateway module call to include WAF:

```hcl
# First create the API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"
  
  api_name                     = "squrl-api"
  environment                  = "prod"
  create_url_lambda_arn        = module.lambda.create_url_lambda_arn
  create_url_lambda_invoke_arn = module.lambda.create_url_lambda_invoke_arn
  redirect_lambda_arn          = module.lambda.redirect_lambda_arn
  redirect_lambda_invoke_arn   = module.lambda.redirect_lambda_invoke_arn
  analytics_lambda_arn         = module.lambda.analytics_lambda_arn
  analytics_lambda_invoke_arn  = module.lambda.analytics_lambda_invoke_arn
  
  # Reference the WAF Web ACL
  web_acl_arn = module.api_gateway_waf.web_acl_arn
  
  tags = local.common_tags
}

# Then create the WAF with stage association
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"

  environment            = "prod"
  api_gateway_stage_arn = module.api_gateway.stage_arn
  
  rate_limit_requests_per_5min        = 2000
  create_rate_limit_requests_per_5min = 1000
  
  tags = local.common_tags
}
```

## Monitoring and Alerting

The module creates several CloudWatch alarms:

### Blocked Requests Alarm
- **Metric**: `AWS/WAFV2/BlockedRequests`
- **Threshold**: 100 requests (configurable)
- **Purpose**: Detect potential attacks or misconfigurations

### Rate Limit Alarms
- **Global Rate Limit**: 10 blocked requests (configurable)
- **Create URL Rate Limit**: 5 blocked requests (configurable)
- **Purpose**: Monitor legitimate traffic hitting rate limits

### Custom Dashboards

```hcl
# Example CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "waf_monitoring" {
  dashboard_name = "squrl-api-waf-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", module.api_gateway_waf.web_acl_name, "Region", data.aws_region.current.name],
            [".", "BlockedRequests", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "WAF Request Volume"
        }
      }
    ]
  })
}
```

## Cost Considerations

### WAF Pricing
- **Web ACL**: $1.00 per month per Web ACL
- **Rules**: $0.60 per month per rule (this module has 7-10 rules)
- **Requests**: $0.60 per million requests processed
- **Bot Control**: Additional $1.00 per million requests (if enabled)

### Cost Optimization Tips
1. **Disable Bot Control** in development environments
2. **Reduce log retention** for non-production environments  
3. **Use geo-restrictions** only when necessary
4. **Monitor rule effectiveness** and disable unused rules

## Security Best Practices

### Rate Limiting Strategy
1. **Global Limits**: Set based on expected peak traffic + 20% buffer
2. **Endpoint-specific Limits**: Create endpoint should be more restrictive
3. **Geographic Limits**: Apply stricter limits to high-risk regions

### IP Management
```hcl
module "api_gateway_waf" {
  source = "./modules/api-gateway-waf"
  # ... other configuration ...
  
  # Allow trusted IPs to bypass rate limits
  rate_limit_exempted_ips = [
    "203.0.113.0/24",  # Office network
    "198.51.100.10/32" # Monitoring service
  ]
  
  # Block known bad actors
  ip_blocklist = [
    "192.0.2.0/24"     # Known attack source
  ]
}
```

### Log Analysis
Enable WAF logging and analyze patterns:

```bash
# Query blocked requests in CloudWatch Logs
aws logs filter-log-events \
  --log-group-name "/aws/wafv2/squrl-api-gateway-prod" \
  --filter-pattern "{ $.action = \"BLOCK\" }" \
  --start-time $(date -d '1 hour ago' +%s)000
```

## Troubleshooting

### Common Issues

1. **False Positives**: Legitimate requests being blocked
   ```hcl
   # Add IP allowlist for known good sources
   ip_allowlist = ["trusted.partner.com/32"]
   ```

2. **High Costs**: Unexpected WAF charges
   ```hcl
   # Disable expensive features in non-prod
   enable_bot_control = var.environment == "prod" ? true : false
   ```

3. **Rate Limit Too Restrictive**: Users hitting limits during peak usage
   ```hcl
   # Increase limits or add exemptions
   rate_limit_requests_per_5min = var.environment == "prod" ? 5000 : 2000
   ```

### Validation Commands

```bash
# Check WAF association
aws wafv2 get-web-acl-for-resource \
  --resource-arn "arn:aws:apigateway:region::/restapis/api-id/stages/stage-name"

# Test rate limiting
for i in {1..1100}; do
  curl -s "https://api.example.com/create" > /dev/null
  echo "Request $i sent"
done
```

## Outputs

| Output | Description |
|--------|-------------|
| `web_acl_arn` | ARN of the WAF Web ACL |
| `web_acl_id` | ID of the WAF Web ACL |
| `web_acl_name` | Name of the WAF Web ACL |
| `waf_log_group_name` | CloudWatch log group name |
| `cloudwatch_metrics_config` | Metrics configuration for monitoring |
| `waf_configuration` | Summary of WAF configuration |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources

- `aws_wafv2_web_acl`
- `aws_wafv2_web_acl_association`
- `aws_wafv2_web_acl_logging_configuration`
- `aws_cloudwatch_log_group`
- `aws_cloudwatch_metric_alarm`

## Contributing

When adding new rules or modifying existing ones:

1. **Priority Management**: Use priorities 110+ for custom rules
2. **Testing**: Test in development environment first
3. **Documentation**: Update rule table in this README
4. **Monitoring**: Add appropriate CloudWatch metrics

## License

This module is part of the Squrl project and follows the same licensing terms.