# Example usage of the API Gateway WAF module
# This file demonstrates various ways to use the module

# Example 1: Basic usage with API Gateway module integration
module "api_gateway" {
  source = "../api_gateway"

  api_name                     = "squrl-api-${var.environment}"
  environment                  = var.environment
  create_url_lambda_arn        = var.create_url_lambda_arn
  create_url_lambda_invoke_arn = var.create_url_lambda_invoke_arn
  redirect_lambda_arn          = var.redirect_lambda_arn
  redirect_lambda_invoke_arn   = var.redirect_lambda_invoke_arn
  analytics_lambda_arn         = var.analytics_lambda_arn
  analytics_lambda_invoke_arn  = var.analytics_lambda_invoke_arn

  # Reference the WAF Web ACL
  web_acl_arn = module.api_gateway_waf.web_acl_arn

  tags = var.tags
}

module "api_gateway_waf" {
  source = "../api-gateway-waf"

  environment           = var.environment
  api_gateway_stage_arn = module.api_gateway.stage_arn

  # Basic rate limiting
  rate_limit_requests_per_5min        = 2000
  create_rate_limit_requests_per_5min = 1000

  tags = var.tags
}

# Example 2: Production environment with advanced settings
module "api_gateway_waf_prod" {
  source = "../api-gateway-waf"

  environment           = "prod"
  api_gateway_stage_arn = var.api_gateway_stage_arn

  # Stricter rate limiting for production
  rate_limit_requests_per_5min        = 5000
  create_rate_limit_requests_per_5min = 2000
  scanner_detection_404_threshold     = 100

  # Request size limits
  max_request_body_size_kb = 16
  max_uri_length           = 4096

  # Geographic restrictions for high-risk countries
  enable_geo_restrictions   = true
  geo_restricted_countries  = ["CN", "RU", "KP", "IR"]
  geo_restricted_rate_limit = 200

  # Enable bot control (additional charges apply)
  enable_bot_control           = true
  bot_control_inspection_level = "TARGETED"

  # Comprehensive logging and monitoring
  enable_waf_logging     = true
  waf_log_retention_days = 90
  alarm_sns_topic_arn    = var.alerts_sns_topic_arn

  # Custom alarm thresholds
  blocked_requests_alarm_threshold  = 500
  rate_limit_alarm_threshold        = 50
  create_rate_limit_alarm_threshold = 20

  # IP allowlist for trusted sources
  ip_allowlist = [
    "203.0.113.0/24",  # Office network
    "198.51.100.10/32" # Monitoring service
  ]

  # Block known bad actors
  ip_blocklist = [
    "192.0.2.0/24" # Known attack source
  ]

  tags = merge(var.tags, {
    CostCenter  = "security"
    Criticality = "high"
  })
}

# Example 3: Development environment with relaxed settings
module "api_gateway_waf_dev" {
  source = "../api-gateway-waf"

  environment           = "dev"
  api_gateway_stage_arn = var.dev_api_gateway_stage_arn

  # Relaxed limits for development
  rate_limit_requests_per_5min        = 10000
  create_rate_limit_requests_per_5min = 5000
  scanner_detection_404_threshold     = 500

  # Reduced logging retention to save costs
  waf_log_retention_days = 7

  # No geographic restrictions in dev
  enable_geo_restrictions = false

  # No bot control in dev (save costs)
  enable_bot_control = false

  # Higher alarm thresholds for dev
  blocked_requests_alarm_threshold  = 1000
  rate_limit_alarm_threshold        = 100
  create_rate_limit_alarm_threshold = 50

  tags = merge(var.tags, {
    Environment   = "dev"
    CostOptimized = "true"
  })
}

# Example 4: WAF-only deployment (no immediate API Gateway association)
module "api_gateway_waf_standalone" {
  source = "../api-gateway-waf"

  environment           = var.environment
  api_gateway_stage_arn = null # No association initially

  # Standard configuration
  rate_limit_requests_per_5min        = 3000
  create_rate_limit_requests_per_5min = 1500

  tags = var.tags
}

# Associate WAF with API Gateway stage later
resource "aws_wafv2_web_acl_association" "manual_association" {
  count        = var.enable_manual_waf_association ? 1 : 0
  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = module.api_gateway_waf_standalone.web_acl_arn
}

# Example 5: Multiple environments with conditional configuration
module "api_gateway_waf_conditional" {
  source = "../api-gateway-waf"

  environment           = var.environment
  api_gateway_stage_arn = var.api_gateway_stage_arn

  # Environment-specific rate limits
  rate_limit_requests_per_5min        = var.environment == "prod" ? 10000 : 5000
  create_rate_limit_requests_per_5min = var.environment == "prod" ? 5000 : 2500

  # Enable advanced features only in production
  enable_geo_restrictions = var.environment == "prod" ? true : false
  enable_bot_control      = var.environment == "prod" ? true : false

  # Environment-specific logging retention
  waf_log_retention_days = var.environment == "prod" ? 90 : 30

  # Conditional geographic restrictions
  geo_restricted_countries  = var.environment == "prod" ? ["CN", "RU"] : []
  geo_restricted_rate_limit = var.environment == "prod" ? 100 : 1000

  tags = merge(var.tags, {
    Environment = var.environment
    ConfigType  = "conditional"
  })
}

# Variables for examples (these would be defined in variables.tf)
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "api_gateway_stage_arn" {
  description = "API Gateway stage ARN"
  type        = string
}

variable "dev_api_gateway_stage_arn" {
  description = "Development API Gateway stage ARN"
  type        = string
  default     = null
}

variable "alerts_sns_topic_arn" {
  description = "SNS topic for alerts"
  type        = string
  default     = null
}

variable "enable_manual_waf_association" {
  description = "Enable manual WAF association"
  type        = bool
  default     = false
}

variable "create_url_lambda_arn" {
  description = "Create URL Lambda ARN"
  type        = string
}

variable "create_url_lambda_invoke_arn" {
  description = "Create URL Lambda invoke ARN"
  type        = string
}

variable "redirect_lambda_arn" {
  description = "Redirect Lambda ARN"
  type        = string
}

variable "redirect_lambda_invoke_arn" {
  description = "Redirect Lambda invoke ARN"
  type        = string
}

variable "analytics_lambda_arn" {
  description = "Analytics Lambda ARN"
  type        = string
}

variable "analytics_lambda_invoke_arn" {
  description = "Analytics Lambda invoke ARN"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}