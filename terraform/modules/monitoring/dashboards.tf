# CloudWatch Dashboards for comprehensive monitoring

# API Performance Dashboard
resource "aws_cloudwatch_dashboard" "api_performance" {
  count          = var.enable_dashboards ? 1 : 0
  dashboard_name = "${var.service_name}-api-performance-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Request Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Request Count & Errors"
          period  = 300
          stat    = "Sum"
          annotations = {
            horizontal = [
              {
                label = "Error Rate > 1%"
                value = var.error_rate_threshold
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name, "Method", "POST", "Resource", "/create"],
            ["...", "GET", ".", "/{short_code}"],
            ["...", "GET", ".", "/stats/{short_code}"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Requests by Endpoint"
          period  = 300
          stat    = "Sum"
        }
      },
      
      # Row 2: Latency Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_name, {"stat": "p50"}],
            ["...", {"stat": "p95"}],
            ["...", {"stat": "p99"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Latency Percentiles"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 2000
            }
          }
          annotations = {
            horizontal = [
              {
                label = "P99 Threshold"
                value = var.latency_p99_threshold_ms
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names.create_url, {"stat": "Average"}],
            ["...", var.lambda_function_names.redirect, {"stat": "Average"}],
            ["...", var.lambda_function_names.analytics, {"stat": "Average"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Duration"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "OriginLatency", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", {"stat": "Average"}],
            [".", "ViewerRequestLatency", ".", ".", ".", ".", {"stat": "p95"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "CloudFront Latency"
          period  = 300
        }
      },
      
      # Row 3: Geographic Distribution
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Global Request Distribution"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "CloudFront Cache Hit Rate"
          period  = 300
          stat    = "Average"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
          annotations = {
            horizontal = [
              {
                label = "Target Cache Hit Rate"
                value = var.cache_hit_rate_threshold
              }
            ]
          }
        }
      },
      
      # Row 4: Error Analysis
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_gateway_name, "Method", "POST", "Resource", "/create"],
            [".", "5XXError", ".", ".", ".", ".", "."],
            ["...", "GET", ".", "/{short_code}"],
            [".", "4XXError", ".", ".", ".", ".", "."],
            ["...", "GET", ".", "/stats/{short_code}"],
            [".", "5XXError", ".", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Error Distribution by Endpoint"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names.create_url],
            ["...", var.lambda_function_names.redirect],
            ["...", var.lambda_function_names.analytics],
            [".", "Throttles", ".", var.lambda_function_names.create_url],
            ["...", var.lambda_function_names.redirect],
            ["...", var.lambda_function_names.analytics]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Errors & Throttles"
          period  = 300
          stat    = "Sum"
        }
      }
    ]
  })

  # Note: CloudWatch dashboards don't support tags in current AWS provider
}

# Abuse Detection Dashboard
resource "aws_cloudwatch_dashboard" "abuse_detection" {
  count          = var.enable_dashboards && var.enable_abuse_detection ? 1 : 0
  dashboard_name = "${var.service_name}-abuse-detection-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Request Volume Monitoring
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/apigateway/${var.api_gateway_name}'\n| fields @timestamp, @message, requestId, ip, status\n| filter @message like /(?i)(bot|crawler|scanner|abuse)/\n| stats count() as suspicious_requests by ip\n| sort suspicious_requests desc\n| limit 10"
          region  = var.aws_region
          title   = "Top 10 IPs - Suspicious Activity"
          view    = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/apigateway/${var.api_gateway_name}'\n| fields @timestamp, ip, status, userAgent\n| filter @timestamp > @timestamp - 1h\n| stats count() as total_requests, count() as error_requests by ip, status\n| filter status like /4[0-9][0-9]/\n| sort error_requests desc\n| limit 20"
          region  = var.aws_region
          title   = "High Error Rate IPs (Last Hour)"
          view    = "table"
        }
      },
      
      # Row 2: WAF Metrics (if available)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = var.waf_web_acl_name != null ? [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_web_acl_name, "Rule", "RateLimitRule", "Region", "CloudFront"],
            [".", "AllowedRequests", ".", ".", ".", ".", ".", "."],
          ] : [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = var.waf_web_acl_name != null ? "WAF Blocked vs Allowed Requests" : "CloudFront Requests (WAF not configured)"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["${var.service_name}/${var.environment}/Security", "AbuseDetections_high_volume", "Environment", var.environment, "Service", var.service_name, "PatternType", "high_volume"],
            [".", "AbuseDetections_scanner", ".", ".", ".", ".", ".", "scanner"],
            [".", "AbuseDetections_suspicious_patterns", ".", ".", ".", ".", ".", "suspicious_patterns"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Custom Abuse Detection Metrics"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name, "Method", "POST", "Resource", "/create"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "URL Creation Rate (Monitor for Spam)"
          period  = 300
          stat    = "Sum"
          annotations = {
            horizontal = [
              {
                label = "High Volume Threshold"
                value = var.abuse_urls_per_ip_threshold * 10  # Approximate total threshold
              }
            ]
          }
        }
      },
      
      # Row 3: Detailed Analysis
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 8
        properties = {
          query   = "SOURCE '/aws/apigateway/${var.api_gateway_name}'\n| fields @timestamp, ip, method, resource, status, userAgent, responseTime\n| filter @timestamp > @timestamp - 2h\n| stats count() as request_count, avg(responseTime) as avg_response_time by ip, userAgent\n| sort request_count desc\n| limit 50"
          region  = var.aws_region
          title   = "Detailed Request Analysis - Last 2 Hours"
          view    = "table"
        }
      },
      
      # Row 4: Geographic Analysis
      {
        type   = "log"
        x      = 0
        y      = 20
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/apigateway/${var.api_gateway_name}'\n| fields @timestamp, ip, country, city, status\n| filter @timestamp > @timestamp - 1d\n| stats count() as requests by country, city\n| sort requests desc\n| limit 20"
          region  = var.aws_region
          title   = "Top Request Sources by Geography"
          view    = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 20
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/apigateway/${var.api_gateway_name}'\n| fields @timestamp, ip, status\n| filter @timestamp > @timestamp - 1h AND status like /404/\n| stats count() as not_found_requests by ip\n| sort not_found_requests desc\n| limit 15"
          region  = var.aws_region
          title   = "Top 404 Sources (Scanner Detection)"
          view    = "table"
        }
      }
    ]
  })

  # Note: CloudWatch dashboards don't support tags in current AWS provider
}

# Cost Tracking Dashboard
resource "aws_cloudwatch_dashboard" "cost_tracking" {
  count          = var.enable_dashboards ? 1 : 0
  dashboard_name = "${var.service_name}-cost-tracking-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Overall Cost Trend
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "AmazonApiGateway"],
            ["...", "AWS Lambda"],
            ["...", "AmazonDynamoDB"],
            ["...", "AmazonCloudFront"],
            ["...", "AmazonKinesis"]
          ]
          view    = "timeSeries"
          stacked = true
          region  = "us-east-1"  # Billing metrics are only in us-east-1
          title   = "Estimated Daily Costs by Service"
          period  = 86400  # 24 hours
          stat    = "Maximum"
          annotations = {
            horizontal = [
              {
                label = var.environment == "dev" ? "Dev Cost Threshold ($${var.monthly_cost_threshold_dev}/month)" : "Prod Cost Threshold ($${var.monthly_cost_threshold_prod}/month)"
                value = var.environment == "dev" ? var.monthly_cost_threshold_dev / 30 : var.monthly_cost_threshold_prod / 30
              }
            ]
          }
        }
      },
      
      # Row 2: Service-specific metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names.create_url],
            ["...", var.lambda_function_names.redirect],
            ["...", var.lambda_function_names.analytics]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations (Cost Driver)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Requests (Cost Driver)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Capacity Units (Cost Driver)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 6
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"],
            [".", "BytesUploaded", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "CloudFront Data Transfer (Cost Driver)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      },
      
      # Row 3: Cost Analysis Table
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/cost-monitoring/${var.service_name}-${var.environment}'\n| fields @timestamp, service_name, cost_usd, usage_quantity, usage_unit\n| filter @timestamp > @timestamp - 24h\n| stats sum(cost_usd) as daily_cost, sum(usage_quantity) as total_usage by service_name, usage_unit\n| sort daily_cost desc"
          region  = var.aws_region
          title   = "Daily Cost Breakdown by Service"
          view    = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '/aws/cost-monitoring/${var.service_name}-${var.environment}'\n| fields @timestamp, cost_usd\n| filter @timestamp > @timestamp - 30d\n| stats sum(cost_usd) as total_cost by datefloor(@timestamp, 1d) as day\n| sort day asc"
          region  = var.aws_region
          title   = "30-Day Cost Trend"
          view    = "table"
        }
      },
      
      # Row 4: Usage Efficiency Metrics
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names.create_url, {"stat": "Average"}],
            [".", "MemoryUtilization", ".", ".", {"stat": "Average"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Efficiency (Cost Optimization)"
          period  = 3600  # 1 hour
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ReadThrottledEvents", "TableName", var.dynamodb_table_name],
            [".", "WriteThrottledEvents", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Throttling (Efficiency Monitor)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Kinesis", "IncomingRecords", "StreamName", var.kinesis_stream_name],
            [".", "PutRecords.TotalRecords", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Kinesis Usage (Cost Driver)"
          period  = 3600  # 1 hour
          stat    = "Sum"
        }
      }
    ]
  })

  # Note: CloudWatch dashboards don't support tags in current AWS provider
}

# System Health Overview Dashboard
resource "aws_cloudwatch_dashboard" "system_health" {
  count          = var.enable_dashboards ? 1 : 0
  dashboard_name = "${var.service_name}-system-health-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: High-level Health Indicators
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "Total Requests (Last Hour)"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_gateway_name],
            [".", "5XXError", ".", "."]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "Error Count (Last Hour)"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_name, {"stat": "p99"}]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "P99 Latency (Last Hour)"
          period  = 3600
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "Cache Hit Rate %"
          period  = 3600
          stat    = "Average"
        }
      },
      
      # Row 2: Service Status Grid
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 8
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names.create_url, {"label": "Create URL"}],
            [".", "Errors", ".", ".", {"label": "Create URL Errors"}],
            [".", "Invocations", ".", var.lambda_function_names.redirect, {"label": "Redirect"}],
            [".", "Errors", ".", ".", {"label": "Redirect Errors"}],
            [".", "Invocations", ".", var.lambda_function_names.analytics, {"label": "Analytics"}],
            [".", "Errors", ".", ".", {"label": "Analytics Errors"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Functions Health"
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 8
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "ReadThrottledEvents", ".", "."],
            [".", "WriteThrottledEvents", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Performance"
          period  = 300
          stat    = "Sum"
        }
      }
    ]
  })

  # Note: CloudWatch dashboards don't support tags in current AWS provider
}