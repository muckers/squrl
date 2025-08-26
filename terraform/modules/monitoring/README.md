# Squrl Monitoring Module

A comprehensive monitoring and observability module for the Squrl URL shortener service, providing real-time monitoring, abuse detection, cost tracking, and automated alerting capabilities.

## Overview

This Terraform module implements production-ready monitoring for the Squrl service with the following components:

- **CloudWatch Dashboards**: Visual monitoring for API performance, abuse detection, cost tracking, and system health
- **CloudWatch Alarms**: Automated alerting for errors, latency, throttling, and cost thresholds
- **Abuse Detection**: Real-time monitoring and automated response to malicious activity
- **Cost Monitoring**: Track spending against budget thresholds with anomaly detection
- **Centralized Logging**: Structured logs with automated analysis and insights
- **X-Ray Tracing**: Distributed tracing for performance analysis

## Features

### 📊 Comprehensive Dashboards

1. **API Performance Dashboard**
   - Request counts by endpoint
   - Latency percentiles (P50, P95, P99)
   - Error rates by status code
   - Geographic distribution via CloudFront

2. **Abuse Detection Dashboard**
   - Top requesting IPs
   - URL creation patterns
   - Scanner detection (404 rates)
   - WAF blocked requests

3. **Cost Tracking Dashboard**
   - Service-specific cost breakdown
   - Daily spending trends
   - Usage efficiency metrics
   - Budget threshold monitoring

4. **System Health Dashboard**
   - High-level service status
   - Lambda function health
   - DynamoDB performance
   - Infrastructure metrics

### 🚨 Advanced Alerting

- **Error Rate Monitoring**: API Gateway 4XX/5XX errors
- **Performance Alerts**: Latency threshold breaches
- **Resource Throttling**: Lambda and DynamoDB throttling detection
- **Cost Thresholds**: Daily/monthly spending alerts
- **Abuse Detection**: Automated security threat alerts
- **Composite Alarms**: Service health overview

### 🛡️ Security Monitoring

- **Real-time Abuse Detection**: EventBridge-triggered analysis
- **IP Reputation Checking**: Threat intelligence integration
- **Automated Response**: WAF IP blocking and rate limiting
- **Pattern Recognition**: Bot detection, scanner identification
- **Behavioral Analysis**: Anomalous request pattern detection

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │   EventBridge   │    │      SNS        │
│   Dashboards    │    │   Rules         │    │   Notifications │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │    Lambda       │    │   DynamoDB      │
│   Alarms        │    │   Functions     │    │   Tracking      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  ▼
                      ┌─────────────────┐
                      │   CloudWatch    │
                      │   Logs          │
                      └─────────────────┘
```

## Usage

### Basic Configuration

```hcl
module "monitoring" {
  source = "../modules/monitoring"

  # Core configuration
  environment    = "dev"
  service_name   = "squrl"
  
  # Resource identification
  api_gateway_name              = module.api_gateway.rest_api_name
  api_gateway_stage_name        = module.api_gateway.stage_name
  cloudfront_distribution_id    = module.cloudfront.distribution_id
  dynamodb_table_name          = module.dynamodb.table_name
  kinesis_stream_name          = aws_kinesis_stream.analytics.name
  
  lambda_function_names = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    analytics  = module.analytics_lambda.function_name
  }
  
  # Notification configuration
  alarm_email_endpoints = ["admin@example.com", "ops@example.com"]
  
  # Enable features
  enable_dashboards      = true
  enable_alarms         = true
  enable_abuse_detection = true
  enable_xray_tracing   = true
  
  tags = local.common_tags
}
```

### Advanced Configuration

```hcl
module "monitoring" {
  source = "../modules/monitoring"

  # Core configuration
  environment    = "prod"
  service_name   = "squrl"
  
  # Resource identification (required)
  api_gateway_name              = module.api_gateway.rest_api_name
  cloudfront_distribution_id    = module.cloudfront.distribution_id
  dynamodb_table_name          = module.dynamodb.table_name
  kinesis_stream_name          = aws_kinesis_stream.analytics.name
  waf_web_acl_name             = module.cloudfront.web_acl_name
  
  lambda_function_names = {
    create_url = module.create_url_lambda.function_name
    redirect   = module.redirect_lambda.function_name
    analytics  = module.analytics_lambda.function_name
  }
  
  # Custom thresholds
  error_rate_threshold        = 2.0  # 2% error rate
  latency_p99_threshold_ms    = 800  # 800ms P99 latency
  monthly_cost_threshold_prod = 1000 # $1000/month
  
  # Abuse detection configuration
  abuse_requests_per_ip_threshold = 2000  # 2000 requests/hour per IP
  abuse_404_rate_threshold       = 60     # 60% 404 rate
  abuse_urls_per_ip_threshold    = 200    # 200 URLs/hour per IP
  
  # Advanced features
  enable_custom_metrics         = true
  enable_cost_anomaly_detection = true
  enable_abuse_detection        = true
  enable_xray_tracing          = true
  
  # Log retention
  log_retention_days = 30
  
  # Existing SNS topic (optional)
  alarm_sns_topic_arn = aws_sns_topic.existing_alerts.arn
  
  tags = local.common_tags
}
```

## Monitoring Components

### CloudWatch Alarms

#### Critical Alarms (Immediate Response Required)
- `api-gateway-server-errors`: 5XX errors (threshold: >1 in 5 minutes)
- `lambda-high-error-rate`: Combined error rate >1%
- `dynamodb-errors`: DynamoDB system errors
- `service-health`: Composite alarm for overall service health

#### High Priority Alarms
- `api-gateway-high-error-rate`: 4XX errors (threshold: >10 in 5 minutes)
- `high-latency`: P99 latency >500ms
- `lambda-throttling`: Lambda function throttling
- `dynamodb-throttling`: DynamoDB throttling events

#### Medium Priority Alarms
- `cloudfront-low-cache-hit-rate`: Cache hit rate <80%
- `abuse-high-request-volume`: Suspicious request volume
- `high-daily-cost`: Daily cost threshold breach

### Dashboards

Access dashboards through the AWS Console or use the URLs provided in module outputs:

```hcl
# Dashboard URLs
output "dashboard_urls" {
  value = module.monitoring.dashboard_urls
}
```

### Log Analysis

Pre-configured CloudWatch Logs Insights queries:

```sql
-- Error Analysis
fields @timestamp, @message, level, error_type, request_id, function_name
| filter level = "ERROR"
| stats count() by error_type, function_name
| sort count() desc

-- Performance Analysis  
fields @timestamp, duration, function_name, memory_used, request_id
| filter duration > 100
| stats avg(duration), max(duration) by function_name
| sort avg(duration) desc

-- Abuse Pattern Analysis
fields @timestamp, source_ip, user_agent, endpoint, status_code
| stats count() as request_count by source_ip
| sort request_count desc
| limit 50
```

## Cost Monitoring

### Budget Thresholds

Environment-specific cost thresholds:

- **Development**: $50/month (configurable via `monthly_cost_threshold_dev`)
- **Production**: $500/month (configurable via `monthly_cost_threshold_prod`)

### Cost Anomaly Detection

Automatically detects unusual spending patterns and sends alerts when:
- Daily costs exceed 150% of normal patterns
- Service costs anomaly >$10
- Specific resource usage spikes

### Cost Optimization Insights

The cost dashboard provides:
- Service-specific spending breakdown
- Usage efficiency metrics (Lambda memory utilization, DynamoDB throttling)
- Data transfer costs
- Request volume correlations

## Abuse Detection

### Detection Patterns

1. **High Volume Requests**
   - Threshold: 1000 requests per 5 minutes per IP
   - Response: Temporary rate limiting

2. **URL Creation Spam** 
   - Threshold: 100 URL creations per hour per IP
   - Response: IP blocking for 60 minutes

3. **Scanner Behavior**
   - Pattern: >50% 404 error rate with >10 requests
   - Response: IP blocking for 2 hours

4. **Bot Detection**
   - Pattern: Suspicious user agents (bot, crawler, scanner)
   - Response: Enhanced monitoring and alerting

### Automated Response

When abuse is detected, the system automatically:

1. **Logs the incident** in dedicated abuse detection log group
2. **Identifies malicious IPs** using behavioral analysis
3. **Updates WAF rules** to block offending IPs (if WAF enabled)
4. **Sends notifications** to security team
5. **Publishes metrics** for trending analysis

### Manual Investigation

Use the abuse detection dashboard and log insights for manual investigation:

```sql
-- Top offending IPs in last hour
fields @timestamp, source_ip, user_agent, status_code
| filter @timestamp > @timestamp - 1h
| stats count() as requests, 
        count(status_code = "404") as not_found_requests,
        count(status_code = "429") as rate_limited_requests 
  by source_ip, user_agent
| sort requests desc
| limit 20
```

## Integration with WAF

When `waf_web_acl_name` is provided, the module enables:

- **Automatic IP blocking** for detected abuse
- **Rate limit adjustment** during high-traffic periods  
- **Real-time threat response** via Lambda functions
- **WAF metrics integration** in dashboards

## Operational Runbooks

### High Error Rate Response

1. **Check the API Performance Dashboard**
2. **Review recent deployments** in the time window
3. **Examine error logs** using CloudWatch Logs Insights
4. **Check Lambda function health** and memory usage
5. **Verify DynamoDB performance** and capacity

### Abuse Detection Response

1. **Access Abuse Detection Dashboard**
2. **Identify top offending IPs**
3. **Review automated actions taken** 
4. **Investigate patterns** using log analysis
5. **Update WAF rules** if needed
6. **Document incidents** for pattern analysis

### Cost Threshold Response

1. **Check Cost Tracking Dashboard**
2. **Identify cost drivers** (Lambda, API Gateway, DynamoDB)
3. **Review usage patterns** for anomalies
4. **Optimize resource configuration** if needed
5. **Update budget thresholds** if growth expected

## Troubleshooting

### Common Issues

#### Alarms Not Triggering
```bash
# Check alarm configuration
aws cloudwatch describe-alarms --alarm-names "squrl-api-gateway-high-error-rate-dev"

# Verify metrics are being published
aws cloudwatch get-metric-statistics --namespace AWS/ApiGateway \
  --metric-name 4XXError --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z --period 300 --statistics Sum
```

#### Dashboard Not Loading
- Check IAM permissions for CloudWatch
- Verify resource names match actual deployed resources
- Confirm region consistency across all resources

#### Abuse Detection Not Working
- Verify EventBridge rules are enabled
- Check Lambda function logs for errors
- Confirm DynamoDB tables have proper permissions

### Log Analysis Queries

```sql
-- Recent Lambda errors
fields @timestamp, @message, @requestId
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50

-- API Gateway latency analysis
fields @timestamp, @duration, @requestId
| filter @type = "END" 
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)

-- Cost analysis by service
fields @timestamp, service, cost
| stats sum(cost) as total_cost by service
| sort total_cost desc
```

## Security Considerations

- **Log Encryption**: All logs encrypted with customer-managed KMS keys
- **IAM Permissions**: Least-privilege access for all Lambda functions
- **Network Isolation**: Abuse detection functions use VPC endpoints where possible
- **Data Retention**: Configurable retention periods with automatic cleanup
- **Access Control**: Dashboard access controlled via IAM policies

## Scaling Considerations

- **Log Volume**: Monitor CloudWatch Logs ingestion costs
- **Lambda Concurrency**: Set appropriate reserved concurrency for abuse detection
- **DynamoDB Capacity**: Abuse tracking tables use on-demand billing
- **Alert Fatigue**: Tune thresholds based on actual usage patterns
- **Geographic Distribution**: Consider multi-region monitoring for global services

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | - | Environment name (dev/staging/prod) |
| `service_name` | string | "squrl" | Service name for tagging and naming |
| `api_gateway_name` | string | - | API Gateway REST API name |
| `cloudfront_distribution_id` | string | - | CloudFront distribution ID |
| `lambda_function_names` | object | - | Map of Lambda function names |
| `enable_dashboards` | bool | true | Enable CloudWatch dashboards |
| `enable_alarms` | bool | true | Enable CloudWatch alarms |
| `enable_abuse_detection` | bool | true | Enable abuse detection monitoring |
| `error_rate_threshold` | number | 1 | Error rate threshold percentage |
| `latency_p99_threshold_ms` | number | 500 | P99 latency threshold in ms |
| `monthly_cost_threshold_dev` | number | 50 | Monthly cost threshold for dev ($) |
| `abuse_requests_per_ip_threshold` | number | 1000 | Request threshold per IP for abuse |
| `alarm_email_endpoints` | list(string) | [] | Email addresses for alarm notifications |

See [variables.tf](./variables.tf) for complete variable documentation.

## Outputs Reference

| Output | Description |
|--------|-------------|
| `dashboard_urls` | URLs to access CloudWatch dashboards |
| `alerts_sns_topic_arn` | SNS topic ARN for alerts |
| `critical_alarms` | List of critical alarm names |
| `log_groups` | Map of created log group names |
| `abuse_detection_resources` | Abuse detection resource details |
| `monitoring_config` | Summary of monitoring configuration |

See [outputs.tf](./outputs.tf) for complete output documentation.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| archive | ~> 2.0 |

## Contributing

1. Update monitoring thresholds based on actual service behavior
2. Add new abuse detection patterns as needed
3. Enhance cost optimization recommendations  
4. Expand geographic analysis capabilities
5. Integrate with additional threat intelligence sources

## License

This module is part of the Squrl project. See the main project LICENSE for details.