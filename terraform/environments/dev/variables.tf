variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "admin_email" {
  description = "Administrator email for alerts and notifications"
  type        = string
  default     = "admin@example.com"
}

# ========================================
# Security Module Configuration
# ========================================

# Secrets Manager Configuration
variable "enable_secrets_manager" {
  description = "Enable Secrets Manager module for storing application secrets"
  type        = bool
  default     = false  # Disabled by default for dev to save costs
}

variable "application_secrets" {
  description = "Map of application secrets to store in Secrets Manager"
  type = map(object({
    description         = string
    secret_string       = optional(string)
    secret_key_value    = optional(map(string))
    rotation_days       = optional(number)
    create_app_policy   = optional(bool, false)
  }))
  default = {
    # Example secrets for development
    api-keys = {
      description = "Development API keys"
      secret_key_value = {
        github_token = "dev-placeholder-token"
        webhook_secret = "dev-placeholder-secret"
      }
      create_app_policy = true
    }
  }
  sensitive = true
}

# Parameter Store Configuration
variable "enable_parameter_store" {
  description = "Enable Parameter Store module for application configuration"
  type        = bool
  default     = false  # Disabled by default for dev to save costs
}

variable "application_parameters" {
  description = "Map of application parameters to store in Parameter Store"
  type = map(object({
    value       = string
    type        = string
    description = optional(string)
    tier        = optional(string)
    kms_key_id  = optional(string)
  }))
  default = {
    # Development configuration parameters
    "config/database/max_connections" = {
      value       = "10"
      type        = "String"
      description = "Maximum database connections for dev"
    }
    "config/api/rate_limit" = {
      value       = "1000"
      type        = "String"
      description = "API rate limit for development environment"
    }
    "config/cache/ttl_seconds" = {
      value       = "300"
      type        = "String"
      description = "Cache TTL in seconds for dev"
    }
  }
}

variable "feature_flags" {
  description = "Feature flags for the application"
  type        = map(string)
  default = {
    enable_analytics     = "true"
    enable_rate_limiting = "false"  # Disabled in dev for easier testing
    enable_caching      = "false"   # Disabled in dev to avoid complexity
    enable_notifications = "false"  # Disabled in dev
  }
}

# API Gateway WAF Configuration
variable "enable_api_gateway_waf" {
  description = "Enable WAF for API Gateway protection"
  type        = bool
  default     = false  # Disabled by default for dev to save costs
}

variable "waf_rate_limit_requests_per_5min" {
  description = "Global rate limit for WAF (requests per 5 minutes)"
  type        = number
  default     = 10000  # More permissive for dev testing
}

variable "waf_create_rate_limit_requests_per_5min" {
  description = "Rate limit for create URL endpoint (requests per 5 minutes)"
  type        = number
  default     = 1000   # More permissive for dev testing
}

# VPC Endpoints Configuration
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for private AWS service access"
  type        = bool
  default     = false  # Disabled by default for dev due to cost
}

variable "enable_vpc_endpoints_full" {
  description = "Enable all VPC endpoints (interface endpoints have costs)"
  type        = bool
  default     = false  # Only enable gateway endpoints by default
}

# ========================================
# Monitoring and Alerting Configuration
# ========================================

variable "enable_monitoring_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "enable_monitoring_dashboards" {
  description = "Enable CloudWatch dashboards for monitoring"
  type        = bool
  default     = true
}

variable "monthly_cost_threshold_dev" {
  description = "Monthly cost threshold for dev environment alerts (USD)"
  type        = number
  default     = 50
}

variable "error_rate_threshold" {
  description = "Error rate threshold percentage for alarms"
  type        = number
  default     = 5  # 5% error rate threshold for dev
}

variable "latency_p99_threshold_ms" {
  description = "P99 latency threshold in milliseconds for alarms"
  type        = number
  default     = 200  # 200ms P99 latency threshold for dev
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7  # Short retention for dev to save costs
}