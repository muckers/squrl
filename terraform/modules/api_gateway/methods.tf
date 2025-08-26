# API Resources
resource "aws_api_gateway_resource" "create" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  parent_id   = aws_api_gateway_rest_api.squrl_api.root_resource_id
  path_part   = "create"
}

resource "aws_api_gateway_resource" "short_code" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  parent_id   = aws_api_gateway_rest_api.squrl_api.root_resource_id
  path_part   = "{short_code}"
}

resource "aws_api_gateway_resource" "stats" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  parent_id   = aws_api_gateway_rest_api.squrl_api.root_resource_id
  path_part   = "stats"
}

resource "aws_api_gateway_resource" "stats_short_code" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  parent_id   = aws_api_gateway_resource.stats.id
  path_part   = "{short_code}"
}

# ============================================================================
# POST /create - Create URL endpoint
# ============================================================================

resource "aws_api_gateway_method" "create_post" {
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  resource_id   = aws_api_gateway_resource.create.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.create_url.id

  request_models = {
    "application/json" = aws_api_gateway_model.create_url_request.name
  }
}

resource "aws_api_gateway_method_response" "create_post_200" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.create_url_response.name
  }
}

resource "aws_api_gateway_method_response" "create_post_400" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_post.http_method
  status_code = "400"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_method_response" "create_post_500" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_post.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_integration" "create_post" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.create.id
  http_method = aws_api_gateway_method.create_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.create_url_lambda_invoke_arn
}

resource "aws_lambda_permission" "create_post" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.create_url_lambda_arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.squrl_api.execution_arn}/*/*"
}

# ============================================================================
# GET /{short_code} - Redirect endpoint  
# ============================================================================

resource "aws_api_gateway_method" "redirect_get" {
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  resource_id   = aws_api_gateway_resource.short_code.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.short_code" = true
  }
}

resource "aws_api_gateway_method_response" "redirect_get_301" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.redirect_get.http_method
  status_code = "301"

  response_parameters = {
    "method.response.header.Location"                    = true
    "method.response.header.Cache-Control"               = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "redirect_get_404" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.redirect_get.http_method
  status_code = "404"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_method_response" "redirect_get_500" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.redirect_get.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_integration" "redirect_get" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.redirect_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.redirect_lambda_invoke_arn

  request_parameters = {
    "integration.request.path.short_code" = "method.request.path.short_code"
  }
}

resource "aws_lambda_permission" "redirect_get" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.redirect_lambda_arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.squrl_api.execution_arn}/*/*"
}

# ============================================================================
# GET /stats/{short_code} - Analytics endpoint
# ============================================================================

resource "aws_api_gateway_method" "stats_get" {
  rest_api_id   = aws_api_gateway_rest_api.squrl_api.id
  resource_id   = aws_api_gateway_resource.stats_short_code.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.short_code" = true
  }
}

resource "aws_api_gateway_method_response" "stats_get_200" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.stats_short_code.id
  http_method = aws_api_gateway_method.stats_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Cache-Control"               = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.stats_response.name
  }
}

resource "aws_api_gateway_method_response" "stats_get_404" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.stats_short_code.id
  http_method = aws_api_gateway_method.stats_get.http_method
  status_code = "404"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_method_response" "stats_get_500" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.stats_short_code.id
  http_method = aws_api_gateway_method.stats_get.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.error_response.name
  }
}

resource "aws_api_gateway_integration" "stats_get" {
  rest_api_id = aws_api_gateway_rest_api.squrl_api.id
  resource_id = aws_api_gateway_resource.stats_short_code.id
  http_method = aws_api_gateway_method.stats_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn

  request_parameters = {
    "integration.request.path.short_code" = "method.request.path.short_code"
  }
}

resource "aws_lambda_permission" "stats_get" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.analytics_lambda_arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.squrl_api.execution_arn}/*/*"
}