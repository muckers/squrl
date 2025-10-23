# API Gateway Module

This Terraform module creates a complete Amazon API Gateway REST API for the Squrl URL shortener service, following the milestone-02.md specifications.

## Features

- **REST API with 3 endpoints:**
  - `POST /create` - Create shortened URLs
  - `GET /{short_code}` - Redirect to original URLs  
  - `GET /stats/{short_code}` - Get URL analytics

- **AWS Lambda Integration:**
  - Seamless integration with existing Lambda functions
  - AWS_PROXY integration type for optimal performance
  - Proper error handling and response mapping

- **Rate Limiting (IP-based):**
  - 100 req/sec sustained rate limit
  - 200 req/sec burst capacity  
  - No API keys required - completely free service
  - Per-endpoint throttling configuration

- **Request/Response Validation:**
  - JSON Schema validation for POST requests
  - Parameter validation for GET requests
  - Comprehensive error response models

- **CORS Support:**
  - Full CORS configuration for browser access
  - Configurable origins, methods, and headers
  - Proper preflight OPTIONS handling

- **Monitoring & Logging:**
  - CloudWatch integration for API Gateway logs
  - Access logging with detailed request/response info
  - X-Ray tracing support
  - Detailed CloudWatch metrics

- **Production Ready:**
  - Multiple deployment stages (dev, staging, prod)
  - Environment-specific configurations
  - Proper IAM roles and permissions
  - Caching support for production environments

## Usage

```hcl
module "api_gateway" {
  source = "./modules/api_gateway"

  # Basic configuration
  api_name    = "squrl-api"
  environment = "dev"
  stage_name  = "v1"

  # Lambda function integration
  create_url_lambda_arn         = module.create_url_lambda.function_arn
  create_url_lambda_invoke_arn  = module.create_url_lambda.invoke_arn
  redirect_lambda_arn           = module.redirect_lambda.function_arn  
  redirect_lambda_invoke_arn    = module.redirect_lambda.invoke_arn
  get_stats_lambda_arn          = module.get_stats_lambda.function_arn
  get_stats_lambda_invoke_arn   = module.get_stats_lambda.invoke_arn

  # Rate limiting configuration
  throttle_burst_limit = 200
  throttle_rate_limit  = 100

  # Optional configurations
  enable_access_logs   = true
  enable_xray_tracing  = true
  log_retention_days   = 14

  tags = {
    Environment = "dev"
    Project     = "squrl"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| api_name | Name of the API Gateway REST API | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| create_url_lambda_arn | ARN of the create-url Lambda function | `string` | n/a | yes |
| create_url_lambda_invoke_arn | Invoke ARN of the create-url Lambda function | `string` | n/a | yes |
| redirect_lambda_arn | ARN of the redirect Lambda function | `string` | n/a | yes |
| redirect_lambda_invoke_arn | Invoke ARN of the redirect Lambda function | `string` | n/a | yes |
| get_stats_lambda_arn | ARN of the get-stats Lambda function | `string` | n/a | yes |
| get_stats_lambda_invoke_arn | Invoke ARN of the get-stats Lambda function | `string` | n/a | yes |
| stage_name | Name of the API Gateway stage | `string` | `"v1"` | no |
| throttle_burst_limit | API throttling burst limit (req/sec) | `number` | `200` | no |
| throttle_rate_limit | API throttling sustained rate limit (req/sec) | `number` | `100` | no |
| enable_access_logs | Enable access logging for API Gateway | `bool` | `true` | no |
| enable_xray_tracing | Enable X-Ray tracing for API Gateway | `bool` | `true` | no |
| log_retention_days | CloudWatch logs retention in days | `number` | `14` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| rest_api_id | The ID of the REST API |
| rest_api_arn | The ARN of the REST API |
| invoke_url | The URL to invoke the API |
| stage_name | The name of the deployment stage |
| usage_plan_id | The ID of the usage plan |
| create_url_endpoint | Complete URL for the create endpoint |
| redirect_url_base | Base URL for redirect endpoints |
| stats_url_base | Base URL for stats endpoints |
| api_configuration | Summary of API configuration |

## API Endpoints

### POST /create
Create a new shortened URL.

**Request Body:**
```json
{
  "url": "https://example.com/very/long/url",
  "custom_code": "optional-custom-code",
  "expires_at": "2024-12-31T23:59:59Z"
}
```

**Response:**
```json
{
  "short_code": "abc123",
  "short_url": "https://your-domain.com/abc123",
  "original_url": "https://example.com/very/long/url",
  "created_at": "2023-10-01T12:00:00Z",
  "expires_at": "2024-12-31T23:59:59Z",
  "click_count": 0
}
```

### GET /{short_code}
Redirect to the original URL.

**Response:** 301 redirect to original URL

### GET /stats/{short_code}
Get analytics for a shortened URL.

**Response:**
```json
{
  "short_code": "abc123",
  "original_url": "https://example.com/very/long/url",
  "created_at": "2023-10-01T12:00:00Z",
  "click_count": 42,
  "last_accessed": "2023-10-02T15:30:00Z",
  "analytics": {
    "daily_clicks": [...],
    "top_referrers": [...],
    "geographic_distribution": [...]
  }
}
```

## Rate Limiting

The API implements IP-based rate limiting without requiring API keys:

- **Sustained Rate:** 100 requests per second
- **Burst Capacity:** 200 requests per second  
- **Per-Endpoint Limits:**
  - `POST /create`: Standard limits
  - `GET /{short_code}`: Higher limits (150 sustained, 400 burst)
  - `GET /stats/{short_code}`: Standard limits

## Caching

Production environments enable response caching:
- **Redirects:** 5-minute cache TTL
- **Stats:** 1-minute cache TTL  
- **Create:** No caching (always fresh)

## Error Handling

All endpoints return consistent error responses:

```json
{
  "error": "ValidationError",
  "message": "Invalid URL format",
  "details": {...},
  "timestamp": "2023-10-01T12:00:00Z",
  "request_id": "req-123456"
}
```

Common HTTP status codes:
- `200` - Success
- `301` - Redirect (for short URL access)
- `400` - Bad Request (validation errors)
- `404` - Not Found (invalid short code)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

## CORS Configuration

The API supports cross-origin requests with the following default settings:
- **Allowed Origins:** `*` (configurable)
- **Allowed Methods:** `GET, POST, OPTIONS`
- **Allowed Headers:** Standard headers plus custom ones
- **Max Age:** 24 hours (86400 seconds)

## Monitoring

The module sets up comprehensive monitoring:

1. **CloudWatch Logs:**
   - API Gateway execution logs
   - Access logs with detailed request/response info

2. **CloudWatch Metrics:**
   - Request count, latency, error rates
   - Per-endpoint metrics
   - Cache hit/miss rates (in production)

3. **X-Ray Tracing:**
   - End-to-end request tracing
   - Performance bottleneck identification
   - Lambda integration visibility

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Existing Lambda functions for create-url, redirect, and analytics
- Proper IAM permissions for API Gateway and Lambda integration

## Notes

- The module is designed for the Squrl URL shortener service following milestone-02.md specifications
- No authentication is required - this is a completely free service with IP-based rate limiting
- The API is optimized for performance with appropriate caching and throttling
- All resources are tagged consistently for cost tracking and management