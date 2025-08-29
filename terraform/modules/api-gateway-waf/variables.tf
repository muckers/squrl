variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "enable_waf" {
  description = "Enable AWS WAF for rate limiting and abuse protection"
  type        = bool
  default     = true
}

variable "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage to associate with WAF (optional)"
  type        = string
  default     = null
}

# WAF Rate Limiting Configuration
variable "rate_limit_requests_per_5min" {
  description = "Maximum requests allowed per IP per 5 minutes"
  type        = number
  default     = 1000
  validation {
    condition     = var.rate_limit_requests_per_5min >= 100 && var.rate_limit_requests_per_5min <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000 requests per 5 minutes"
  }
}

variable "create_rate_limit_requests_per_5min" {
  description = "Maximum create requests allowed per IP per 5 minutes"
  type        = number
  default     = 500
  validation {
    condition     = var.create_rate_limit_requests_per_5min >= 100 && var.create_rate_limit_requests_per_5min <= 20000000
    error_message = "Create rate limit must be between 100 and 20,000,000 requests per 5 minutes"
  }
}

variable "scanner_detection_404_threshold" {
  description = "Number of 404 responses per 5 minutes to trigger scanner detection"
  type        = number
  default     = 50
  validation {
    condition     = var.scanner_detection_404_threshold >= 100 && var.scanner_detection_404_threshold <= 20000000
    error_message = "Scanner detection threshold must be between 100 and 20,000,000 requests per 5 minutes"
  }
}

# Geographic Restrictions (Optional)
variable "enable_geo_restrictions" {
  description = "Enable geographic rate limiting for high-risk countries"
  type        = bool
  default     = false
}

variable "geo_restricted_countries" {
  description = "List of country codes to apply stricter rate limits (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.geo_restricted_countries) == 0 || alltrue([for code in var.geo_restricted_countries : length(code) == 2])
    error_message = "Country codes must be valid ISO 3166-1 alpha-2 codes (2 characters)"
  }
}

variable "geo_restricted_rate_limit" {
  description = "Reduced rate limit for geo-restricted countries"
  type        = number
  default     = 100
  validation {
    condition     = var.geo_restricted_rate_limit >= 100 && var.geo_restricted_rate_limit <= 20000000
    error_message = "Geo-restricted rate limit must be between 100 and 20,000,000 requests per 5 minutes"
  }
}

# Request Size Limits
variable "max_request_body_size_kb" {
  description = "Maximum request body size in KB"
  type        = number
  default     = 8
  validation {
    condition     = var.max_request_body_size_kb > 0 && var.max_request_body_size_kb <= 8192
    error_message = "Request body size must be between 1 and 8192 KB"
  }
}

variable "max_uri_length" {
  description = "Maximum URI length in bytes"
  type        = number
  default     = 2048
  validation {
    condition     = var.max_uri_length > 0 && var.max_uri_length <= 8192
    error_message = "URI length must be between 1 and 8192 bytes"
  }
}

# Bot Control Configuration (Optional - can be expensive)
variable "enable_bot_control" {
  description = "Enable AWS Bot Control managed rule set (additional charges apply)"
  type        = bool
  default     = false
}

variable "bot_control_inspection_level" {
  description = "Bot control inspection level (COMMON or TARGETED)"
  type        = string
  default     = "COMMON"
  validation {
    condition     = contains(["COMMON", "TARGETED"], var.bot_control_inspection_level)
    error_message = "Bot control inspection level must be COMMON or TARGETED"
  }
}

# Logging Configuration
variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "WAF logs retention in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.waf_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period"
  }
}

# Monitoring and Alerting
variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for WAF alarms (optional)"
  type        = string
  default     = null
}

variable "blocked_requests_alarm_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 100
}

variable "rate_limit_alarm_threshold" {
  description = "Threshold for rate limit alarm"
  type        = number
  default     = 10
}

variable "create_rate_limit_alarm_threshold" {
  description = "Threshold for create URL rate limit alarm"
  type        = number
  default     = 5
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Additional Custom Rules (Optional)
variable "custom_rules" {
  description = "List of custom WAF rules to add"
  type = list(object({
    name     = string
    priority = number
    action   = string # "allow", "block", "count"
    statement = object({
      # This allows for flexible rule definitions
      # Users can define custom byte_match_statement, size_constraint_statement, etc.
      rule_type = string
      config    = map(any)
    })
  }))
  default = []
}

# IP Allowlist (Optional)
variable "ip_allowlist" {
  description = "List of IP addresses/CIDR blocks to always allow (bypasses all other rules)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.ip_allowlist : can(cidrhost(cidr, 0))
    ])
    error_message = "All IP allowlist entries must be valid CIDR blocks"
  }
}

# IP Blocklist (Optional)  
variable "ip_blocklist" {
  description = "List of IP addresses/CIDR blocks to always block"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.ip_blocklist : can(cidrhost(cidr, 0))
    ])
    error_message = "All IP blocklist entries must be valid CIDR blocks"
  }
}

# Rate Limiting Exemptions
variable "rate_limit_exempted_ips" {
  description = "List of IP addresses/CIDR blocks exempt from rate limiting"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.rate_limit_exempted_ips : can(cidrhost(cidr, 0))
    ])
    error_message = "All rate limit exempted IPs must be valid CIDR blocks"
  }
}