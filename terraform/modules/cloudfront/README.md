# CloudFront Module with WAF Rate Limiting

This Terraform module creates a CloudFront distribution with AWS WAF rate limiting rules for the Squrl URL shortener service. It provides comprehensive protection against abuse while maintaining high performance for legitimate users.

## Features

### WAF Protection
- **Global Rate Limiting**: 1000 requests per 5 minutes per IP
- **Create URL Rate Limiting**: 500 requests per 5 minutes per IP for /create endpoint
- **Scanner Detection**: Blocks IPs with high 404 rates (configurable threshold)
- **Request Size Constraints**: Limits request body size and URI length
- **Malformed Request Blocking**: Protects against common attack patterns
- **AWS Managed Rules**: Includes protection against known bad inputs and common attacks
- **Geographic Rate Limiting**: Optional reduced limits for specific countries

### CloudFront Optimization
- **Intelligent Caching**: Different cache policies for redirects, API calls, and stats
- **Compression**: Automatic compression for applicable content types
- **HTTP/2 Support**: Enhanced performance with HTTP/2
- **Security Headers**: Comprehensive security headers via response headers policy
- **Custom Error Pages**: Branded error responses for better user experience

### Monitoring & Observability
- **WAF Logging**: Configurable logging to CloudWatch
- **CloudWatch Alarms**: Automated alerts for blocked requests and rate limits
- **Access Logs**: Optional S3 logging for detailed analysis
- **Metrics**: Built-in CloudWatch metrics for monitoring

## Usage

### Basic Configuration

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  environment              = var.environment
  api_gateway_domain_name  = module.api_gateway.domain_name
  api_gateway_stage_name   = "v1"

  tags = {
    Environment = var.environment
    Project     = "squrl"
    Owner       = "platform-team"
  }
}
```

### Advanced Configuration

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  # Basic Configuration
  environment              = var.environment
  api_gateway_domain_name  = module.api_gateway.domain_name
  api_gateway_stage_name   = "v1"

  # Custom Domain
  custom_domain_name = "squrl.example.com"
  certificate_arn    = aws_acm_certificate.main.arn

  # WAF Configuration  
  enable_waf                           = true
  rate_limit_requests_per_5min         = 2000  # Increased for high traffic
  create_rate_limit_requests_per_5min  = 1000  # Increased create limits
  scanner_detection_404_threshold      = 100   # More lenient scanner detection

  # Geographic Restrictions
  enable_geo_restrictions    = true
  geo_restricted_countries   = ["CN", "RU", "KP"]  # Example restricted countries
  geo_restricted_rate_limit  = 50

  # Performance Settings
  price_class         = "PriceClass_200"  # Include more edge locations
  enable_compression  = true
  http2_enabled      = true
  ipv6_enabled       = true

  # Cache Settings
  redirect_cache_ttl_seconds = 7200     # 2 hours for redirects
  default_cache_ttl_seconds  = 86400    # 24 hours for other content

  # Logging & Monitoring
  enable_waf_logging      = true
  waf_log_retention_days  = 30
  enable_real_time_logs   = false  # Can be expensive

  tags = {
    Environment = var.environment
    Project     = "squrl"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}
```

## Rate Limiting Strategy

The module implements a multi-layered rate limiting approach:

### 1. Global Rate Limiting
- **Limit**: 1000 requests per 5 minutes per IP
- **Purpose**: Prevent overall service abuse
- **Action**: Block requests that exceed the limit

### 2. Endpoint-Specific Limits
- **Create Endpoint**: 500 requests per 5 minutes per IP
- **Purpose**: Prevent URL creation abuse
- **Action**: Block excessive creation requests

### 3. Scanner Detection
- **Trigger**: High 404 response rate (default: 50 per 5 minutes)
- **Purpose**: Detect and block automated scanners
- **Action**: Temporary IP blocking

### 4. Request Size Limits
- **Body Size**: 8KB maximum (configurable)
- **URI Length**: 2048 characters maximum
- **Purpose**: Prevent payload-based attacks

### 5. Geographic Restrictions (Optional)
- **Purpose**: Apply stricter limits to high-risk countries
- **Configuration**: Specify countries and reduced limits
- **Use Case**: Compliance or abuse prevention

## Cache Behaviors

The module implements intelligent caching for optimal performance:

### URL Redirects (`/*`)
- **Cache Duration**: 1 hour (configurable)
- **Purpose**: High cache hit rate for redirects
- **Query Strings**: Ignored for better caching
- **Compression**: Disabled (redirects don't benefit)

### Create Endpoint (`/create*`)
- **Cache Duration**: No caching
- **Purpose**: Always fresh for POST operations
- **Headers**: Full forwarding for API functionality

### Stats Endpoint (`/stats*`)
- **Cache Duration**: 5 minutes
- **Purpose**: Near real-time data with performance
- **Query Strings**: Included in cache key

### Default Behavior
- **Cache Duration**: 24 hours (configurable)
- **Purpose**: General API responses
- **Compression**: Enabled for applicable content

## Security Headers

The module automatically adds comprehensive security headers:

- **HSTS**: Strict Transport Security with preload
- **X-Frame-Options**: Prevent clickjacking
- **X-Content-Type-Options**: Prevent MIME sniffing
- **X-XSS-Protection**: XSS protection for legacy browsers
- **Content Security Policy**: Restrict content sources
- **Permissions Policy**: Limit browser APIs
- **CORS**: Properly configured for API access

## Monitoring & Alerting

### Built-in CloudWatch Alarms

1. **High Blocked Requests**
   - **Threshold**: 100 blocked requests in 5 minutes
   - **Purpose**: Detect potential attacks

2. **Rate Limit Violations**
   - **Threshold**: 10 rate limit triggers in 5 minutes
   - **Purpose**: Monitor abuse patterns

### Custom Monitoring

```hcl
# Add custom alarms
resource "aws_cloudwatch_metric_alarm" "high_4xx_errors" {
  alarm_name          = "squrl-4xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5" # 5% error rate
  alarm_description   = "High 4xx error rate on CloudFront"

  dimensions = {
    DistributionId = module.cloudfront.distribution_id
  }
}
```

## WAF Rule Details

### Rule Priorities and Actions

1. **Priority 10 - Global Rate Limit**: Block after 1000 requests/5min
2. **Priority 20 - Create Rate Limit**: Block after 500 create requests/5min
3. **Priority 30 - Scanner Detection**: Block high 404 rate IPs
4. **Priority 40 - Size Restrictions**: Block oversized requests
5. **Priority 50 - Malformed Requests**: Block suspicious patterns
6. **Priority 60 - Geographic Limits**: Reduced limits for specific countries
7. **Priority 70 - Known Bad Inputs**: AWS managed rule
8. **Priority 80 - Common Rule Set**: AWS managed rule with exclusions

### Rule Customization

Rules can be customized by modifying the variables:

```hcl
# Increase rate limits for high-traffic environments
rate_limit_requests_per_5min = 5000
create_rate_limit_requests_per_5min = 2000

# Adjust scanner detection sensitivity
scanner_detection_404_threshold = 200

# Modify request size limits
max_request_body_size_kb = 16
max_uri_length = 4096
```

## Cost Optimization

### Development Environment
- Use `PriceClass_100` (US, Europe)
- Disable real-time logs
- Set shorter log retention (7-14 days)
- Disable additional CloudWatch metrics

### Production Environment
- Consider `PriceClass_200` for better global performance
- Enable real-time logs if detailed analytics needed
- Set appropriate log retention (30-90 days)
- Enable additional monitoring

### Example Cost Settings

```hcl
# Development - Cost Optimized
price_class               = "PriceClass_100"
enable_real_time_logs    = false
waf_log_retention_days   = 14
enable_cloudwatch_metrics = false

# Production - Performance Optimized
price_class               = "PriceClass_200"
enable_real_time_logs    = true   # If analytics needed
waf_log_retention_days   = 90
enable_cloudwatch_metrics = true
```

## Testing

### Load Testing
Test rate limits with tools like Apache Bench or Artillery:

```bash
# Test global rate limit (should be blocked after 1000 requests)
ab -n 2000 -c 50 https://your-domain.com/test

# Test create endpoint rate limit
ab -n 1000 -c 20 -p create-payload.json -T application/json https://your-domain.com/create
```

### WAF Rule Testing
Use curl to test specific WAF rules:

```bash
# Test size constraints
curl -X POST -d "$(head -c 10240 /dev/urandom | base64)" https://your-domain.com/create

# Test malformed requests  
curl "https://your-domain.com/../../../etc/passwd"

# Test scanner detection (multiple 404s)
for i in {1..60}; do curl "https://your-domain.com/nonexistent$i"; done
```

## Troubleshooting

### Common Issues

1. **403 Errors from WAF**
   - Check CloudWatch WAF logs
   - Verify rate limits aren't too restrictive
   - Review blocked request patterns

2. **Cache Miss Rate Too High**
   - Check cache policy configuration
   - Verify query string handling
   - Review header forwarding

3. **High Origin Load**
   - Increase cache TTLs for redirects
   - Review cache behaviors
   - Check for cache-busting headers

### Debugging Commands

```bash
# Check WAF blocked requests
aws wafv2 get-sampled-requests \
  --web-acl-arn "arn:aws:wafv2:us-east-1:123456789012:global/webacl/squrl-cloudfront-waf-prod/12345" \
  --rule-metric-name "GlobalRateLimit" \
  --scope CLOUDFRONT \
  --time-window StartTime=1609459200,EndTime=1609462800 \
  --max-items 100

# Check CloudFront cache statistics
aws cloudfront get-distribution-config --id E1234567890123
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | - | Environment name (dev/staging/prod) |
| `api_gateway_domain_name` | string | - | API Gateway domain name |
| `enable_waf` | bool | true | Enable WAF protection |
| `rate_limit_requests_per_5min` | number | 1000 | Global rate limit per IP |
| `create_rate_limit_requests_per_5min` | number | 500 | Create endpoint rate limit |
| `scanner_detection_404_threshold` | number | 50 | 404 threshold for scanner detection |
| `enable_geo_restrictions` | bool | false | Enable geographic restrictions |
| `price_class` | string | "PriceClass_100" | CloudFront price class |
| `enable_compression` | bool | true | Enable compression |
| `http2_enabled` | bool | true | Enable HTTP/2 |
| `enable_waf_logging` | bool | true | Enable WAF logging |

## Outputs

| Output | Description |
|--------|-------------|
| `distribution_id` | CloudFront distribution ID |
| `domain_name` | CloudFront domain name |
| `web_acl_arn` | WAF Web ACL ARN |
| `cloudfront_url` | Full CloudFront URL |
| `configuration_summary` | Configuration summary for debugging |

## Integration with API Gateway

The module is designed to work with the API Gateway module. Example integration:

```hcl
# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"
  # ... api gateway configuration
}

# CloudFront with WAF
module "cloudfront" {
  source = "./modules/cloudfront"
  
  api_gateway_domain_name = module.api_gateway.domain_name
  api_gateway_stage_name  = module.api_gateway.stage_name
  
  # Forward WAF Web ACL ARN to API Gateway if needed
  depends_on = [module.api_gateway]
}

# Optional: Associate WAF with API Gateway as well
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count        = var.enable_api_gateway_waf ? 1 : 0
  resource_arn = module.api_gateway.stage_arn
  web_acl_arn  = module.cloudfront.web_acl_arn
}
```

## Best Practices

1. **Start Conservative**: Begin with lower rate limits and increase as needed
2. **Monitor Closely**: Watch for false positives in the first few days
3. **Test Thoroughly**: Test all WAF rules in a staging environment
4. **Regular Review**: Review WAF logs and adjust rules monthly
5. **Geographic Considerations**: Be careful with geographic restrictions for global services
6. **Emergency Access**: Have a plan to quickly disable WAF rules if needed
7. **Documentation**: Document any custom rule modifications for your team

## License

This module is part of the Squrl URL shortener project and follows the same licensing terms.