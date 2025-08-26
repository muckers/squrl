# Abuse Detection and Security Monitoring Resources

# CloudWatch Event Rules for real-time abuse detection
resource "aws_cloudwatch_event_rule" "suspicious_activity" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name        = "${var.service_name}-suspicious-activity-${var.environment}"
  description = "Detects suspicious activity patterns in real-time"

  event_pattern = jsonencode({
    source      = ["aws.apigateway"]
    detail-type = ["API Gateway Execution Logs"]
    detail = {
      status = ["404", "429", "403"]
      # Pattern for rapid sequential requests from same IP
      sourceIp = [{
        exists = true
      }]
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-suspicious-activity-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "abuse-detection"
  })
}

# Lambda function for real-time abuse analysis
resource "aws_lambda_function" "realtime_abuse_detector" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  function_name = "${var.service_name}-realtime-abuse-detector-${var.environment}"
  role          = aws_iam_role.realtime_abuse_detector_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = "${path.module}/realtime_abuse_detector.zip"
  source_code_hash = data.archive_file.realtime_abuse_detector_zip[0].output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME     = aws_dynamodb_table.abuse_tracking[0].name
      CLOUDWATCH_LOG_GROUP    = var.enable_abuse_detection ? aws_cloudwatch_log_group.abuse_detection[0].name : ""
      SNS_TOPIC_ARN          = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      ENVIRONMENT            = var.environment
      SERVICE_NAME           = var.service_name
      ABUSE_THRESHOLD_5MIN   = var.abuse_requests_per_ip_threshold / 12  # 5-minute threshold
      ABUSE_THRESHOLD_HOUR   = var.abuse_requests_per_ip_threshold
      URL_CREATION_THRESHOLD = var.abuse_urls_per_ip_threshold
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-realtime-abuse-detector-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Function    = "realtime-abuse-detection"
  })
}

# Zip file for real-time abuse detector
data "archive_file" "realtime_abuse_detector_zip" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/realtime_abuse_detector.zip"
  
  source {
    content = templatefile("${path.module}/templates/realtime_abuse_detector.py", {
      service_name = var.service_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# DynamoDB table for abuse tracking state
resource "aws_dynamodb_table" "abuse_tracking" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name           = "${var.service_name}-abuse-tracking-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ip_address"
  range_key      = "time_window"

  attribute {
    name = "ip_address"
    type = "S"
  }

  attribute {
    name = "time_window"
    type = "S"
  }

  attribute {
    name = "abuse_score_range"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  global_secondary_index {
    name            = "abuse-score-index"
    hash_key        = "abuse_score_range"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-tracking-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "abuse-detection"
  })
}

# IAM role for real-time abuse detector
resource "aws_iam_role" "realtime_abuse_detector_role" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "${var.service_name}-realtime-abuse-detector-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-realtime-abuse-detector-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy_attachment" "realtime_abuse_detector_basic" {
  count      = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  role       = aws_iam_role.realtime_abuse_detector_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "realtime_abuse_detector_custom" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "RealtimeAbuseDetectorCustomPolicy"
  role  = aws_iam_role.realtime_abuse_detector_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.abuse_tracking[0].arn,
          "${aws_dynamodb_table.abuse_tracking[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.abuse_detection[0].arn,
          "${aws_cloudwatch_log_group.abuse_detection[0].arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "${var.service_name}/${var.environment}/Security"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL"
        ]
        Resource = var.waf_web_acl_name != null ? "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:global/webacl/${var.waf_web_acl_name}/*" : "*"
        Condition = var.waf_web_acl_name != null ? {
          StringEquals = {
            "aws:RequestTag/Environment" = var.environment
          }
        } : {}
      }
    ]
  })
}

# EventBridge target to trigger real-time abuse detector
resource "aws_cloudwatch_event_target" "realtime_abuse_detector" {
  count     = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  rule      = aws_cloudwatch_event_rule.suspicious_activity[0].name
  target_id = "RealtimeAbuseDetector"
  arn       = aws_lambda_function.realtime_abuse_detector[0].arn

  input_transformer {
    input_paths = {
      sourceIp   = "$.detail.sourceIp"
      status     = "$.detail.status"
      timestamp  = "$.detail.timestamp"
      userAgent  = "$.detail.userAgent"
      method     = "$.detail.httpMethod"
      resource   = "$.detail.resource"
    }
    
    input_template = jsonencode({
      source_ip  = "<sourceIp>"
      status     = "<status>"
      timestamp  = "<timestamp>"
      user_agent = "<userAgent>"
      method     = "<method>"
      resource   = "<resource>"
      environment = var.environment
      service    = var.service_name
    })
  }
}

resource "aws_lambda_permission" "allow_eventbridge_realtime_abuse" {
  count         = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.realtime_abuse_detector[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.suspicious_activity[0].arn
}

# IP reputation lookup Lambda (for enhanced abuse detection)
resource "aws_lambda_function" "ip_reputation_checker" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  function_name = "${var.service_name}-ip-reputation-checker-${var.environment}"
  role          = aws_iam_role.ip_reputation_checker_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 15
  memory_size   = 128

  filename         = "${path.module}/ip_reputation_checker.zip"
  source_code_hash = data.archive_file.ip_reputation_checker_zip[0].output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.ip_reputation_cache[0].name
      ENVIRONMENT         = var.environment
      SERVICE_NAME        = var.service_name
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-ip-reputation-checker-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Function    = "ip-reputation-check"
  })
}

# DynamoDB table for IP reputation caching
resource "aws_dynamodb_table" "ip_reputation_cache" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name           = "${var.service_name}-ip-reputation-cache-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ip_address"

  attribute {
    name = "ip_address"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-ip-reputation-cache-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "ip-reputation-cache"
  })
}

# Zip file for IP reputation checker
data "archive_file" "ip_reputation_checker_zip" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/ip_reputation_checker.zip"
  
  source {
    content = templatefile("${path.module}/templates/ip_reputation_checker.py", {
      service_name = var.service_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for IP reputation checker
resource "aws_iam_role" "ip_reputation_checker_role" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "${var.service_name}-ip-reputation-checker-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-ip-reputation-checker-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy_attachment" "ip_reputation_checker_basic" {
  count      = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  role       = aws_iam_role.ip_reputation_checker_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ip_reputation_checker_custom" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "IpReputationCheckerCustomPolicy"
  role  = aws_iam_role.ip_reputation_checker_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.ip_reputation_cache[0].arn
      }
    ]
  })
}

# Custom CloudWatch metrics for abuse patterns
resource "aws_cloudwatch_log_metric_filter" "rapid_requests" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name           = "${var.service_name}-rapid-requests-${var.environment}"
  log_group_name = "/aws/apigateway/${var.api_gateway_name}"
  pattern        = "[timestamp, request_id, source_ip, method, resource, status, latency] | [timestamp=*T*, source_ip, method, resource=\"/create\", status=\"2*\"]"

  metric_transformation {
    name          = "RapidURLCreation"
    namespace     = "${var.service_name}/${var.environment}/Abuse"
    value         = "1"
    default_value = "0"
    
    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Endpoint    = "create"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "bot_user_agents" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name           = "${var.service_name}-bot-user-agents-${var.environment}"
  log_group_name = "/aws/apigateway/${var.api_gateway_name}"
  pattern        = "[timestamp, request_id, source_ip, method, resource, status, latency, user_agent=\"*bot*\" || user_agent=\"*crawler*\" || user_agent=\"*spider*\"]"

  metric_transformation {
    name          = "BotRequests"
    namespace     = "${var.service_name}/${var.environment}/Abuse"
    value         = "1"
    default_value = "0"
    
    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Type        = "bot-detection"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "scanner_behavior" {
  count = var.enable_abuse_detection ? 1 : 0
  
  name           = "${var.service_name}-scanner-behavior-${var.environment}"
  log_group_name = "/aws/apigateway/${var.api_gateway_name}"
  pattern        = "[timestamp, request_id, source_ip, method, resource, status=\"404\", latency]"

  metric_transformation {
    name          = "ScannerRequests"
    namespace     = "${var.service_name}/${var.environment}/Abuse"
    value         = "1"
    default_value = "0"
    
    dimensions = {
      Environment = var.environment
      Service     = var.service_name
      Type        = "scanner-detection"
    }
  }
}

# Automated response system for abuse mitigation
resource "aws_lambda_function" "abuse_response_handler" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  function_name = "${var.service_name}-abuse-response-handler-${var.environment}"
  role          = aws_iam_role.abuse_response_handler_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  filename         = "${path.module}/abuse_response_handler.zip"
  source_code_hash = data.archive_file.abuse_response_handler_zip[0].output_base64sha256

  environment {
    variables = {
      DYNAMODB_ABUSE_TABLE = aws_dynamodb_table.abuse_tracking[0].name
      WAF_WEB_ACL_NAME    = var.waf_web_acl_name != null ? var.waf_web_acl_name : ""
      SNS_TOPIC_ARN       = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      ENVIRONMENT         = var.environment
      SERVICE_NAME        = var.service_name
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-response-handler-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Function    = "abuse-response"
  })
}

# Zip file for abuse response handler
data "archive_file" "abuse_response_handler_zip" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/abuse_response_handler.zip"
  
  source {
    content = templatefile("${path.module}/templates/abuse_response_handler.py", {
      service_name = var.service_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for abuse response handler
resource "aws_iam_role" "abuse_response_handler_role" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "${var.service_name}-abuse-response-handler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-response-handler-role-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
  })
}

resource "aws_iam_role_policy_attachment" "abuse_response_handler_basic" {
  count      = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  role       = aws_iam_role.abuse_response_handler_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "abuse_response_handler_custom" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  name  = "AbuseResponseHandlerCustomPolicy"
  role  = aws_iam_role.abuse_response_handler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.abuse_tracking[0].arn,
          "${aws_dynamodb_table.abuse_tracking[0].arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL",
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet"
        ]
        Resource = var.waf_web_acl_name != null ? [
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:global/webacl/${var.waf_web_acl_name}/*",
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:global/ipset/*"
        ] : ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.alarm_sns_topic_arn != null ? var.alarm_sns_topic_arn : aws_sns_topic.alerts[0].arn
      }
    ]
  })
}

# CloudWatch Event Rule to trigger abuse response for high-severity alerts
resource "aws_cloudwatch_event_rule" "abuse_alert_response" {
  count = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  
  name        = "${var.service_name}-abuse-alert-response-${var.environment}"
  description = "Triggers automated response for abuse detection alerts"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [
        {
          prefix = "${var.service_name}-abuse-"
        }
      ]
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.service_name}-abuse-alert-response-${var.environment}"
    Environment = var.environment
    Service     = var.service_name
    Purpose     = "automated-response"
  })
}

resource "aws_cloudwatch_event_target" "abuse_response_handler" {
  count     = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  rule      = aws_cloudwatch_event_rule.abuse_alert_response[0].name
  target_id = "AbuseResponseHandler"
  arn       = aws_lambda_function.abuse_response_handler[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_abuse_response" {
  count         = var.enable_abuse_detection && var.enable_custom_metrics ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.abuse_response_handler[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.abuse_alert_response[0].arn
}