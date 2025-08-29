# WAF Web ACL for API Gateway (Regional)
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = "squrl-api-gateway-waf-${var.environment}"
  scope = "REGIONAL" # Must be REGIONAL for API Gateway

  description = "WAF rules for Squrl API Gateway - rate limiting and abuse protection"

  default_action {
    allow {}
  }

  # Rule 1: Global Rate Limiting (1000 requests per 5 minutes per IP)
  rule {
    name     = "GlobalRateLimit"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_requests_per_5min
        aggregate_key_type = "IP"

        # Optional: Add scope down statement to only count certain requests
        # scope_down_statement {
        #   not_statement {
        #     statement {
        #       byte_match_statement {
        #         field_to_match {
        #           uri_path {}
        #         }
        #         positional_constraint = "CONTAINS"
        #         search_string         = "/health"
        #         text_transformation {
        #           priority = 0
        #           type     = "LOWERCASE"
        #         }
        #       }
        #     }
        #   }
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GlobalRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Create URL Rate Limiting (500 requests per 5 minutes per IP)
  rule {
    name     = "CreateURLRateLimit"
    priority = 20

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.create_rate_limit_requests_per_5min
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/create"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "POST"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CreateURLRateLimit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Scanner Detection (High 404 Rate)
  rule {
    name     = "ScannerDetection"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.scanner_detection_404_threshold
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            field_to_match {
              single_header {
                name = "x-amzn-errortype"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "404"
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ScannerDetection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Request Size Constraints
  rule {
    name     = "RequestSizeRestriction"
    priority = 40

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "GT"
            size                = var.max_request_body_size_kb * 1024
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          size_constraint_statement {
            field_to_match {
              uri_path {}
            }
            comparison_operator = "GT"
            size                = var.max_uri_length
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RequestSizeRestriction"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: Malformed Request Blocking
  rule {
    name     = "MalformedRequestBlocking"
    priority = 50

    action {
      block {}
    }

    statement {
      or_statement {
        # Block requests with path traversal attempts
        statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "CONTAINS"
            search_string         = ".."
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        # Block requests with null bytes
        statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "CONTAINS"
            search_string         = "\u0000"
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        # Block requests with suspicious patterns in query strings
        statement {
          byte_match_statement {
            field_to_match {
              query_string {}
            }
            positional_constraint = "CONTAINS"
            search_string         = "script"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "MalformedRequestBlocking"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: Geographic Rate Limiting (Optional)
  dynamic "rule" {
    for_each = var.enable_geo_restrictions && length(var.geo_restricted_countries) > 0 ? [1] : []

    content {
      name     = "GeographicRateLimit"
      priority = 60

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.geo_restricted_rate_limit
          aggregate_key_type = "IP"

          scope_down_statement {
            geo_match_statement {
              country_codes = var.geo_restricted_countries
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeographicRateLimit"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 7: IP Reputation List (AWS Managed)
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 70

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # Rule 8: Known Bad Actors (AWS Managed Rule)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 80

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 9: Core Rule Set (Basic protections)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 90

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude some rules that might cause false positives for URL shortener
        rule_action_override {
          name = "GenericRFI_BODY"
          action_to_use {
            allow {}
          }
        }
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            allow {}
          }
        }
        # Allow legitimate URLs in body for create endpoint
        rule_action_override {
          name = "GenericLFI_BODY"
          action_to_use {
            allow {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 10: Bot Control (Optional - can be expensive)
  dynamic "rule" {
    for_each = var.enable_bot_control ? [1] : []

    content {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 100

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"

          # Configure bot control rules
          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = var.bot_control_inspection_level
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesBotControlRuleSet"
        sampled_requests_enabled   = true
      }
    }
  }

  # Global visibility config for the Web ACL
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "squrl-api-gateway-waf-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name        = "squrl-api-gateway-waf-${var.environment}"
    Environment = var.environment
    Purpose     = "API Gateway rate limiting and abuse protection"
    Scope       = "REGIONAL"
  })
}

# WAF Association with API Gateway Stage
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf && var.api_gateway_stage_arn != null ? 1 : 0

  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# WAF Logging Configuration
resource "aws_cloudwatch_log_group" "waf_logs" {
  count             = var.enable_waf && var.enable_waf_logging ? 1 : 0
  name              = "/aws/wafv2/squrl-api-gateway-${var.environment}"
  retention_in_days = var.waf_log_retention_days

  tags = merge(var.tags, {
    Name        = "squrl-api-gateway-waf-logs-${var.environment}"
    Environment = var.environment
  })
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_waf && var.enable_waf_logging ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = ["${aws_cloudwatch_log_group.waf_logs[0].arn}:*"]

  # Redact sensitive fields from logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  redacted_fields {
    single_header {
      name = "x-api-key"
    }
  }

  logging_filter {
    default_behavior = "KEEP"

    # Only log blocked requests to reduce noise
    filter {
      behavior = "DROP"
      condition {
        action_condition {
          action = "ALLOW"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}

# CloudWatch Alarms for WAF Metrics
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf ? 1 : 0

  alarm_name          = "squrl-api-waf-blocked-requests-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors blocked requests by API Gateway WAF"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = data.aws_region.current.name
    Rule   = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "squrl-api-waf-blocked-requests-${var.environment}"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_triggered" {
  count = var.enable_waf ? 1 : 0

  alarm_name          = "squrl-api-waf-rate-limit-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors rate limit violations in API Gateway WAF"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = data.aws_region.current.name
    Rule   = "GlobalRateLimit"
  }

  tags = merge(var.tags, {
    Name        = "squrl-api-waf-rate-limit-${var.environment}"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_metric_alarm" "waf_create_rate_limit_triggered" {
  count = var.enable_waf ? 1 : 0

  alarm_name          = "squrl-api-waf-create-rate-limit-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors create URL rate limit violations"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = data.aws_region.current.name
    Rule   = "CreateURLRateLimit"
  }

  tags = merge(var.tags, {
    Name        = "squrl-api-waf-create-rate-limit-${var.environment}"
    Environment = var.environment
  })
}

# Data source to get current region
data "aws_region" "current" {}