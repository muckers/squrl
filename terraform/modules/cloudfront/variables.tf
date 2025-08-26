variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "api_gateway_domain_name" {
  description = "Domain name of the API Gateway to use as origin"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "API Gateway stage name to append to origin path"
  type        = string
  default     = "v1"
}

variable "custom_domain_name" {
  description = "Custom domain name for CloudFront distribution (optional)"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100"
  }
}

variable "enable_waf" {
  description = "Enable AWS WAF for rate limiting and abuse protection"
  type        = bool
  default     = true
}

# WAF Rate Limiting Configuration
variable "rate_limit_requests_per_5min" {
  description = "Maximum requests allowed per IP per 5 minutes"
  type        = number
  default     = 1000
}

variable "create_rate_limit_requests_per_5min" {
  description = "Maximum create requests allowed per IP per 5 minutes"
  type        = number
  default     = 500
}

variable "scanner_detection_404_threshold" {
  description = "Number of 404 responses per 5 minutes to trigger scanner detection"
  type        = number
  default     = 50
}

# Geographic Restrictions (Optional)
variable "enable_geo_restrictions" {
  description = "Enable geographic rate limiting for high-risk countries"
  type        = bool
  default     = false
}

variable "geo_restricted_countries" {
  description = "List of country codes to apply stricter rate limits"
  type        = list(string)
  default     = []
}

variable "geo_restricted_rate_limit" {
  description = "Reduced rate limit for geo-restricted countries"
  type        = number
  default     = 100
}

# Request Size Limits
variable "max_request_body_size_kb" {
  description = "Maximum request body size in KB"
  type        = number
  default     = 8
}

variable "max_uri_length" {
  description = "Maximum URI length"
  type        = number
  default     = 2048
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
}

# Cache Configuration
variable "redirect_cache_ttl_seconds" {
  description = "TTL for redirect responses (301/302) in seconds"
  type        = number
  default     = 3600 # 1 hour
}

variable "error_cache_ttl_seconds" {
  description = "TTL for error responses (4xx/5xx) in seconds"
  type        = number
  default     = 60 # 1 minute
}

variable "default_cache_ttl_seconds" {
  description = "Default TTL for successful responses in seconds"
  type        = number
  default     = 86400 # 24 hours
}

# Compression and Performance
variable "enable_compression" {
  description = "Enable CloudFront compression"
  type        = bool
  default     = true
}

variable "http2_enabled" {
  description = "Enable HTTP/2 support"
  type        = bool
  default     = true
}

variable "ipv6_enabled" {
  description = "Enable IPv6 support"
  type        = bool
  default     = true
}

# Monitoring and Alerting
variable "enable_real_time_logs" {
  description = "Enable CloudFront real-time logs"
  type        = bool
  default     = false # Can be expensive for high traffic
}

variable "enable_cloudwatch_metrics" {
  description = "Enable additional CloudWatch metrics"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}