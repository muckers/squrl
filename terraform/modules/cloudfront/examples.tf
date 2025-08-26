# Example configurations for the CloudFront module

# Example 1: Basic Development Configuration
# Minimal setup for development environment with cost optimization
/*
module "cloudfront_dev" {
  source = "./modules/cloudfront"

  environment              = "dev"
  api_gateway_domain_name  = "abc123def.execute-api.us-east-1.amazonaws.com"
  api_gateway_stage_name   = "v1"

  # Cost-optimized settings for development
  price_class                = "PriceClass_100"
  enable_real_time_logs     = false
  waf_log_retention_days    = 7
  enable_cloudwatch_metrics = false

  # Relaxed rate limits for development
  rate_limit_requests_per_5min        = 2000
  create_rate_limit_requests_per_5min = 1000

  tags = {
    Environment = "dev"
    Project     = "squrl"
    Owner       = "development-team"
    CostCenter  = "engineering"
  }
}
*/

# Example 2: Production Configuration with Custom Domain
# Full-featured setup for production with custom domain and tight security
/*
module "cloudfront_prod" {
  source = "./modules/cloudfront"

  # Basic Configuration
  environment              = "prod"
  api_gateway_domain_name  = "prod-api.execute-api.us-east-1.amazonaws.com"
  api_gateway_stage_name   = "v1"

  # Custom Domain Setup
  custom_domain_name = "squrl.example.com"
  certificate_arn    = aws_acm_certificate.prod.arn

  # Production WAF Settings
  enable_waf                          = true
  rate_limit_requests_per_5min        = 1000  # Standard rate limit
  create_rate_limit_requests_per_5min = 300   # Stricter for URL creation
  scanner_detection_404_threshold     = 25    # More sensitive scanner detection

  # Geographic Restrictions for High-Risk Countries
  enable_geo_restrictions   = true
  geo_restricted_countries  = ["CN", "RU", "KP", "IR"] # Example countries
  geo_restricted_rate_limit = 50

  # Performance Optimization
  price_class                   = "PriceClass_200"  # Better global performance
  enable_compression           = true
  http2_enabled               = true
  ipv6_enabled                = true
  redirect_cache_ttl_seconds  = 3600    # 1 hour cache for redirects
  default_cache_ttl_seconds   = 86400   # 24 hour default cache

  # Enhanced Monitoring
  enable_waf_logging        = true
  waf_log_retention_days   = 90
  enable_real_time_logs    = true
  enable_cloudwatch_metrics = true

  tags = {
    Environment = "prod"
    Project     = "squrl"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Criticality = "high"
    Backup      = "required"
  }
}
*/

# Example 3: High-Traffic Configuration
# Configuration for services expecting very high traffic
/*
module "cloudfront_high_traffic" {
  source = "./modules/cloudfront"

  # Basic Configuration  
  environment              = "prod"
  api_gateway_domain_name  = "prod-api.execute-api.us-east-1.amazonaws.com"
  api_gateway_stage_name   = "v1"

  # High Traffic Rate Limits
  rate_limit_requests_per_5min        = 10000  # Very high global limit
  create_rate_limit_requests_per_5min = 2000   # High creation limit
  scanner_detection_404_threshold     = 500    # Less sensitive for high traffic

  # Maximum Performance Settings
  price_class                   = "PriceClass_All"  # All edge locations
  enable_compression           = true
  http2_enabled               = true
  ipv6_enabled                = true
  redirect_cache_ttl_seconds  = 7200    # 2 hours for better cache hit rate
  default_cache_ttl_seconds   = 172800  # 48 hours for static content

  # Request Size Limits - More Generous
  max_request_body_size_kb = 16   # 16KB for larger payloads
  max_uri_length          = 4096  # Longer URIs supported

  # Full Monitoring Suite
  enable_waf_logging        = true
  waf_log_retention_days   = 30
  enable_real_time_logs    = true    # Important for high-traffic monitoring
  enable_cloudwatch_metrics = true

  tags = {
    Environment = "prod"
    Project     = "squrl"
    Owner       = "platform-team"
    TrafficTier = "high"
    Monitoring  = "enhanced"
  }
}
*/

# Example 4: Security-Focused Configuration
# Maximum security configuration for sensitive environments
/*
module "cloudfront_security_focused" {
  source = "./modules/cloudfront"

  # Basic Configuration
  environment              = "prod"
  api_gateway_domain_name  = "secure-api.execute-api.us-east-1.amazonaws.com"
  api_gateway_stage_name   = "v1"

  # Strict Rate Limiting
  rate_limit_requests_per_5min        = 500   # Conservative global limit
  create_rate_limit_requests_per_5min = 100   # Very strict creation limit
  scanner_detection_404_threshold     = 10    # Highly sensitive scanner detection

  # Geographic Restrictions - Comprehensive
  enable_geo_restrictions   = true
  geo_restricted_countries  = [
    "CN", "RU", "KP", "IR", "SY", "VE", "MM", "AF", "BY"
  ]
  geo_restricted_rate_limit = 20  # Very low limit for restricted countries

  # Strict Request Size Limits
  max_request_body_size_kb = 4     # Small request bodies only
  max_uri_length          = 1024   # Short URIs only

  # Performance vs Security Balance
  price_class                   = "PriceClass_100"  # Cost-effective
  enable_compression           = true
  http2_enabled               = true
  ipv6_enabled                = false  # Disable IPv6 for additional control
  redirect_cache_ttl_seconds  = 1800   # 30 minutes - shorter cache
  default_cache_ttl_seconds   = 3600   # 1 hour - shorter default cache

  # Comprehensive Logging
  enable_waf_logging        = true
  waf_log_retention_days   = 180  # 6 months retention for security analysis
  enable_real_time_logs    = true
  enable_cloudwatch_metrics = true

  tags = {
    Environment   = "prod"
    Project      = "squrl"
    Owner        = "security-team"
    SecurityTier = "high"
    Compliance   = "required"
    AuditLevel   = "full"
  }
}
*/

# Example 5: Multi-Region Configuration
# Configuration that could be used across multiple regions
/*
module "cloudfront_multi_region" {
  source = "./modules/cloudfront"

  # Basic Configuration
  environment              = var.environment
  api_gateway_domain_name  = var.primary_region == "us-east-1" ? 
                            module.api_gateway_us_east.domain_name : 
                            module.api_gateway_eu_west.domain_name
  api_gateway_stage_name   = "v1"

  # Dynamic Configuration Based on Region
  price_class = var.primary_region == "us-east-1" ? "PriceClass_200" : "PriceClass_100"

  # Regional Rate Limit Adjustments
  rate_limit_requests_per_5min = var.region_traffic_multiplier * 1000
  create_rate_limit_requests_per_5min = var.region_traffic_multiplier * 500

  # Conditional Geographic Restrictions
  enable_geo_restrictions = var.enable_geo_restrictions
  geo_restricted_countries = var.geo_restricted_countries
  geo_restricted_rate_limit = 100

  # Environment-Specific Settings
  enable_waf_logging        = var.environment == "prod" ? true : false
  waf_log_retention_days   = var.environment == "prod" ? 90 : 14
  enable_real_time_logs    = var.environment == "prod" ? true : false

  tags = merge(var.common_tags, {
    Environment = var.environment
    Region      = var.primary_region
    Project     = "squrl"
  })
}

# Supporting variables for multi-region example
variable "primary_region" {
  description = "Primary region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "region_traffic_multiplier" {
  description = "Traffic multiplier based on expected regional traffic"
  type        = number
  default     = 1.0
}

variable "enable_geo_restrictions" {
  description = "Enable geographic restrictions"
  type        = bool
  default     = false
}

variable "geo_restricted_countries" {
  description = "Countries to apply restrictions to"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
*/

# Example 6: Integration with API Gateway WAF
# Shows how to use the same WAF for both CloudFront and API Gateway
/*
module "cloudfront_with_api_gateway_waf" {
  source = "./modules/cloudfront"

  environment              = "prod"
  api_gateway_domain_name  = module.api_gateway.domain_name
  api_gateway_stage_name   = "v1"

  # Standard configuration
  rate_limit_requests_per_5min        = 1000
  create_rate_limit_requests_per_5min = 500

  tags = {
    Environment = "prod"
    Project     = "squrl"
  }
}

# Associate the same WAF with API Gateway for defense in depth
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = module.api_gateway.stage_arn
  web_acl_arn  = module.cloudfront_with_api_gateway_waf.web_acl_arn
}
*/

# Example 7: Testing Configuration
# Configuration optimized for load testing and validation
/*
module "cloudfront_testing" {
  source = "./modules/cloudfront"

  environment              = "test"
  api_gateway_domain_name  = "test-api.execute-api.us-east-1.amazonaws.com"
  api_gateway_stage_name   = "v1"

  # Relaxed Limits for Testing
  rate_limit_requests_per_5min        = 5000   # High for load testing
  create_rate_limit_requests_per_5min = 2000   # High for create testing
  scanner_detection_404_threshold     = 1000   # Very lenient

  # Disable Geographic Restrictions for Global Testing
  enable_geo_restrictions = false

  # Short Cache Times for Testing
  redirect_cache_ttl_seconds = 60     # 1 minute for quick testing
  default_cache_ttl_seconds  = 300    # 5 minutes for quick iteration

  # Enhanced Logging for Test Analysis
  enable_waf_logging        = true
  waf_log_retention_days   = 7        # Short retention for cost
  enable_real_time_logs    = false    # Cost optimization
  enable_cloudwatch_metrics = true    # Important for test metrics

  tags = {
    Environment = "test"
    Project     = "squrl"
    Purpose     = "load-testing"
    AutoDelete  = "7days"  # Cleanup after testing
  }
}
*/