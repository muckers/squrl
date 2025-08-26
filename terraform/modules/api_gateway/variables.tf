variable "api_name" {
  description = "Name of the API Gateway REST API"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "create_url_lambda_arn" {
  description = "ARN of the create-url Lambda function"
  type        = string
}

variable "create_url_lambda_invoke_arn" {
  description = "Invoke ARN of the create-url Lambda function"
  type        = string
}

variable "redirect_lambda_arn" {
  description = "ARN of the redirect Lambda function"
  type        = string
}

variable "redirect_lambda_invoke_arn" {
  description = "Invoke ARN of the redirect Lambda function"
  type        = string
}

variable "analytics_lambda_arn" {
  description = "ARN of the analytics Lambda function"
  type        = string
}

variable "analytics_lambda_invoke_arn" {
  description = "Invoke ARN of the analytics Lambda function"
  type        = string
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "enable_access_logs" {
  description = "Enable access logging for API Gateway"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 14
}

variable "throttle_burst_limit" {
  description = "API throttling burst limit (requests per second)"
  type        = number
  default     = 200
}

variable "throttle_rate_limit" {
  description = "API throttling sustained rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "List of allowed methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "OPTIONS"]
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
}

variable "cors_max_age" {
  description = "CORS preflight cache duration in seconds"
  type        = number
  default     = 86400
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Usage plan configuration variables
variable "usage_plan_name" {
  description = "Name of the usage plan"
  type        = string
  default     = null # Will be generated if not provided
}

variable "usage_plan_description" {
  description = "Description of the usage plan"
  type        = string
  default     = "Default usage plan for Squrl API - IP-based rate limiting"
}

# Quota settings (optional - can be null for no quota)
variable "quota_limit" {
  description = "Number of requests allowed per quota period (null for no quota)"
  type        = number
  default     = null
}

variable "quota_period" {
  description = "Quota period (DAY, WEEK, MONTH)"
  type        = string
  default     = "DAY"
  validation {
    condition     = var.quota_period == null || contains(["DAY", "WEEK", "MONTH"], var.quota_period)
    error_message = "Quota period must be DAY, WEEK, or MONTH"
  }
}

variable "quota_offset" {
  description = "Number of requests subtracted from the given limit in the initial time period"
  type        = number
  default     = 0
}

# WAF Integration
variable "web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with this API Gateway (optional)"
  type        = string
  default     = null
}