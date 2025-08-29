variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
  validation {
    condition     = var.environment == "prod"
    error_message = "This configuration is only for production environment."
  }
}

variable "admin_email" {
  description = "Administrator email for alerts and notifications"
  type        = string
}

# ========================================
# Security Module Configuration
# ========================================

# Secrets Manager Configuration
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
    # Production secrets (values should be provided via terraform.tfvars)
    api-keys = {
      description = "Production API keys and tokens"
      secret_key_value = {
        github_token   = "REPLACE_WITH_ACTUAL_TOKEN"
        webhook_secret = "REPLACE_WITH_ACTUAL_SECRET"
        api_key        = "REPLACE_WITH_ACTUAL_API_KEY"
      }
      rotation_days     = 90  # Rotate every 90 days
      create_app_policy = true
    }
    database-credentials = {
      description = "Database connection credentials"
      secret_key_value = {
        username = "REPLACE_WITH_DB_USERNAME"
        password = "REPLACE_WITH_DB_PASSWORD"
      }
      rotation_days     = 30  # More frequent rotation for DB creds
      create_app_policy = true
    }
  }
  sensitive = true
}

variable "enable_secret_rotation" {
  description = "Enable automatic secret rotation for production"
  type        = bool
  default     = true
}

# Parameter Store Configuration
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
    # Production configuration parameters
    "config/database/max_connections" = {
      value       = "100"
      type        = "String"
      description = "Maximum database connections for production"
    }
    "config/api/rate_limit" = {
      value       = "10000"
      type        = "String"
      description = "API rate limit for production environment"
    }
    "config/cache/ttl_seconds" = {
      value       = "3600"
      type        = "String"
      description = "Cache TTL in seconds for production"
    }
    "config/monitoring/error_threshold" = {
      value       = "1"
      type        = "String"
      description = "Error rate threshold percentage for production alerts"
    }
    "config/security/session_timeout" = {
      value       = "1800"
      type        = "SecureString"
      description = "Session timeout in seconds (encrypted)"
    }
  }
}

variable "feature_flags" {
  description = "Feature flags for the application"
  type        = map(string)
  default = {
    enable_analytics     = "true"
    enable_rate_limiting = "true"   # Enabled for production security
    enable_caching      = "true"    # Enabled for production performance
    enable_notifications = "true"   # Enabled for production monitoring
    enable_audit_logging = "true"   # Enabled for production compliance
  }
}

# API Gateway WAF Configuration
variable "waf_rate_limit_requests_per_5min" {
  description = "Global rate limit for WAF (requests per 5 minutes)"
  type        = number
  default     = 50000  # Production rate limit
}

variable "waf_create_rate_limit_requests_per_5min" {
  description = "Rate limit for create URL endpoint (requests per 5 minutes)"
  type        = number
  default     = 5000   # Production create URL rate limit
}

variable "waf_scanner_detection_404_threshold" {
  description = "Number of 404s before blocking scanner IPs"
  type        = number
  default     = 10     # Stricter threshold for production
}

variable "enable_geo_restrictions" {
  description = "Enable geographic restrictions in WAF"
  type        = bool
  default     = false  # Can be enabled based on business requirements
}

variable "geo_restricted_countries" {
  description = "List of country codes to restrict access from"
  type        = list(string)
  default     = []     # Add country codes as needed (e.g., ["CN", "RU"])
}

variable "enable_bot_control" {
  description = "Enable AWS WAF Bot Control managed rule group"
  type        = bool
  default     = true   # Enable for production
}

variable "bot_control_inspection_level" {
  description = "Bot control inspection level (COMMON or TARGETED)"
  type        = string
  default     = "COMMON"
  validation {
    condition     = contains(["COMMON", "TARGETED"], var.bot_control_inspection_level)
    error_message = "Bot control inspection level must be COMMON or TARGETED."
  }
}

variable "waf_log_retention_days" {
  description = "WAF log retention in days"
  type        = number
  default     = 90
}

# VPC Endpoints Configuration
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for private AWS service access"
  type        = bool
  default     = true   # Enable for production security
}

variable "create_vpc_for_endpoints" {
  description = "Create a new VPC for VPC endpoints"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway for internet access from private subnets"
  type        = bool
  default     = true
}

variable "enable_lambda_vpc_endpoint" {
  description = "Enable VPC endpoint for Lambda service"
  type        = bool
  default     = false  # Optional, can be expensive
}

# ========================================
# Lambda Function Configuration
# ========================================

variable "lambda_log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "warn"
  validation {
    condition     = contains(["trace", "debug", "info", "warn", "error"], var.lambda_log_level)
    error_message = "Lambda log level must be one of: trace, debug, info, warn, error."
  }
}

# Create URL Lambda Configuration
variable "create_url_lambda_memory_size" {
  description = "Memory size for create URL Lambda function"
  type        = number
  default     = 512  # Higher memory for production performance
}

variable "create_url_lambda_timeout" {
  description = "Timeout for create URL Lambda function"
  type        = number
  default     = 15   # Slightly higher timeout for production
}

variable "create_url_lambda_reserved_concurrency" {
  description = "Reserved concurrency for create URL Lambda"
  type        = number
  default     = 50   # Reserve capacity for production
}

variable "create_url_lambda_provisioned_concurrency" {
  description = "Provisioned concurrency configuration for create URL Lambda"
  type = object({
    provisioned_concurrent_executions = number
    qualifier                         = string
  })
  default = null  # Can be enabled for consistent performance
}

# Redirect Lambda Configuration
variable "redirect_lambda_memory_size" {
  description = "Memory size for redirect Lambda function"
  type        = number
  default     = 256  # Higher memory for production performance
}

variable "redirect_lambda_timeout" {
  description = "Timeout for redirect Lambda function"
  type        = number
  default     = 10   # Higher timeout for production
}

variable "redirect_lambda_reserved_concurrency" {
  description = "Reserved concurrency for redirect Lambda"
  type        = number
  default     = 100  # Higher reservation for high-traffic redirects
}

variable "redirect_lambda_provisioned_concurrency" {
  description = "Provisioned concurrency configuration for redirect Lambda"
  type = object({
    provisioned_concurrent_executions = number
    qualifier                         = string
  })
  default = null  # Can be enabled for consistent performance
}

# Analytics Lambda Configuration
variable "analytics_lambda_memory_size" {
  description = "Memory size for analytics Lambda function"
  type        = number
  default     = 1024  # Higher memory for analytics processing
}

variable "analytics_lambda_timeout" {
  description = "Timeout for analytics Lambda function"
  type        = number
  default     = 60   # Higher timeout for batch processing
}

variable "analytics_lambda_reserved_concurrency" {
  description = "Reserved concurrency for analytics Lambda"
  type        = number
  default     = 20   # Moderate reservation for analytics
}

variable "analytics_lambda_provisioned_concurrency" {
  description = "Provisioned concurrency configuration for analytics Lambda"
  type = object({
    provisioned_concurrent_executions = number
    qualifier                         = string
  })
  default = null
}

# ========================================
# Kinesis Configuration
# ========================================

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 2  # Multiple shards for production throughput
}

variable "kinesis_retention_period" {
  description = "Data retention period for Kinesis stream (hours)"
  type        = number
  default     = 168  # 7 days retention for production
}

# ========================================
# Monitoring and Logging Configuration
# ========================================

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway and Lambda"
  type        = bool
  default     = true  # Enable for production observability
}

variable "api_gateway_log_retention_days" {
  description = "API Gateway log retention in days"
  type        = number
  default     = 90  # Longer retention for production
}

# ========================================
# S3 Configuration
# ========================================

variable "enable_s3_mfa_delete" {
  description = "Enable MFA delete for S3 bucket"
  type        = bool
  default     = false  # Requires root user to enable, can be set manually
}