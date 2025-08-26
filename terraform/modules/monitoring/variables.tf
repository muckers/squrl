# Core configuration variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service_name" {
  description = "Name of the service"
  type        = string
  default     = "squrl"
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# Resource identification variables
variable "api_gateway_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway deployment stage"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
}

variable "lambda_function_names" {
  description = "Map of Lambda function names by type"
  type = object({
    create_url = string
    redirect   = string
    analytics  = string
  })
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  type        = string
}

variable "waf_web_acl_name" {
  description = "Name of the WAF Web ACL (if enabled)"
  type        = string
  default     = null
}

# Log retention variables
variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch log retention value."
  }
}

# Alarm configuration
variable "enable_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_email_endpoints" {
  description = "List of email endpoints for alarm notifications"
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications (if not provided, will create one)"
  type        = string
  default     = null
}

# Thresholds for alarms
variable "error_rate_threshold" {
  description = "Error rate threshold percentage (0-100) for triggering alarms"
  type        = number
  default     = 1
  validation {
    condition     = var.error_rate_threshold >= 0 && var.error_rate_threshold <= 100
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "latency_p99_threshold_ms" {
  description = "P99 latency threshold in milliseconds for triggering alarms"
  type        = number
  default     = 500
  validation {
    condition     = var.latency_p99_threshold_ms > 0
    error_message = "Latency threshold must be positive."
  }
}

variable "lambda_throttle_threshold" {
  description = "Lambda throttle threshold percentage for triggering alarms"
  type        = number
  default     = 5
  validation {
    condition     = var.lambda_throttle_threshold >= 0 && var.lambda_throttle_threshold <= 100
    error_message = "Lambda throttle threshold must be between 0 and 100."
  }
}

variable "dynamodb_throttle_threshold" {
  description = "DynamoDB throttle threshold for triggering alarms"
  type        = number
  default     = 1
  validation {
    condition     = var.dynamodb_throttle_threshold >= 0
    error_message = "DynamoDB throttle threshold must be non-negative."
  }
}

# Cost monitoring variables
variable "monthly_cost_threshold_dev" {
  description = "Monthly cost threshold in USD for dev environment"
  type        = number
  default     = 50
  validation {
    condition     = var.monthly_cost_threshold_dev > 0
    error_message = "Monthly cost threshold must be positive."
  }
}

variable "monthly_cost_threshold_prod" {
  description = "Monthly cost threshold in USD for production environment"
  type        = number
  default     = 500
  validation {
    condition     = var.monthly_cost_threshold_prod > 0
    error_message = "Monthly cost threshold must be positive."
  }
}

variable "daily_cost_threshold_multiplier" {
  description = "Multiplier for daily cost threshold (daily_threshold = monthly_threshold * multiplier / 30)"
  type        = number
  default     = 1.5
  validation {
    condition     = var.daily_cost_threshold_multiplier > 0
    error_message = "Daily cost threshold multiplier must be positive."
  }
}

# Abuse detection variables
variable "enable_abuse_detection" {
  description = "Enable abuse detection monitoring"
  type        = bool
  default     = true
}

variable "abuse_requests_per_ip_threshold" {
  description = "Request count threshold per IP for abuse detection"
  type        = number
  default     = 1000
  validation {
    condition     = var.abuse_requests_per_ip_threshold > 0
    error_message = "Abuse request threshold must be positive."
  }
}

variable "abuse_404_rate_threshold" {
  description = "404 rate threshold percentage for scanner detection"
  type        = number
  default     = 50
  validation {
    condition     = var.abuse_404_rate_threshold >= 0 && var.abuse_404_rate_threshold <= 100
    error_message = "404 rate threshold must be between 0 and 100."
  }
}

variable "abuse_urls_per_ip_threshold" {
  description = "URL creation threshold per IP per hour for abuse detection"
  type        = number
  default     = 100
  validation {
    condition     = var.abuse_urls_per_ip_threshold > 0
    error_message = "URLs per IP threshold must be positive."
  }
}

# Dashboard configuration
variable "enable_dashboards" {
  description = "Enable CloudWatch dashboards"
  type        = bool
  default     = true
}

variable "dashboard_time_range" {
  description = "Default time range for dashboards"
  type        = string
  default     = "PT3H"
  validation {
    condition = can(regex("^PT\\d+[HM]$", var.dashboard_time_range))
    error_message = "Dashboard time range must be in ISO 8601 duration format (e.g., PT3H, PT30M)."
  }
}

# Advanced monitoring features
variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing integration in dashboards"
  type        = bool
  default     = true
}

variable "enable_custom_metrics" {
  description = "Enable custom application metrics"
  type        = bool
  default     = true
}

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection"
  type        = bool
  default     = true
}

# Regional configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Performance thresholds for monitoring
variable "cache_hit_rate_threshold" {
  description = "Minimum cache hit rate threshold percentage"
  type        = number
  default     = 80
  validation {
    condition     = var.cache_hit_rate_threshold >= 0 && var.cache_hit_rate_threshold <= 100
    error_message = "Cache hit rate threshold must be between 0 and 100."
  }
}

variable "api_gateway_latency_threshold_ms" {
  description = "API Gateway latency threshold in milliseconds"
  type        = number
  default     = 200
  validation {
    condition     = var.api_gateway_latency_threshold_ms > 0
    error_message = "API Gateway latency threshold must be positive."
  }
}

# Resource naming
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Suffix for resource names"
  type        = string
  default     = ""
}