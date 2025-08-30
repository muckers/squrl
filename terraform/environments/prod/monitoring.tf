# Simplified monitoring configuration for Squrl URL Shortener
# Provides essential operational visibility while maintaining privacy compliance
# This file replaces the complex monitoring module with 85% fewer components

# Essential Alarm #1: Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.environment == "prod" ? 1 : 0

  alarm_name          = "squrl-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Lambda function errors across all functions"
  
  dimensions = {
    # This will aggregate errors across all Lambda functions
  }

  treat_missing_data = "notBreaching"

  tags = {
    Environment = var.environment
    Service     = "squrl"
    Component   = "monitoring"
    Privacy     = "compliant"
  }
}

# Essential Alarm #2: DynamoDB Throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  count = var.environment == "prod" ? 1 : 0

  alarm_name          = "squrl-dynamodb-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "DynamoDB throttling events"

  treat_missing_data = "notBreaching"

  tags = {
    Environment = var.environment
    Service     = "squrl"
    Component   = "monitoring"
    Privacy     = "compliant"
  }
}

# Essential Alarm #3: API Gateway 5XX Errors
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  count = var.environment == "prod" ? 1 : 0

  alarm_name          = "squrl-api-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "API Gateway 5XX server errors"

  treat_missing_data = "notBreaching"

  tags = {
    Environment = var.environment
    Service     = "squrl"
    Component   = "monitoring"
    Privacy     = "compliant"
  }
}

# Single Basic Health Dashboard
resource "aws_cloudwatch_dashboard" "health" {
  count = var.environment == "prod" ? 1 : 0
  
  dashboard_name = "squrl-health-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            [".", "Errors", { stat = "Sum" }],
            ["AWS/ApiGateway", "Count", { stat = "Sum" }],
            [".", "5XXError", { stat = "Sum" }],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Service Health Overview"
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
}

# Note: Log groups are already created by the Lambda module
# We just need to ensure 3-day retention for privacy compliance
# These are managed in terraform/modules/lambda/main.tf