# S3 Static Website Hosting Module

This Terraform module creates and configures an S3 bucket for static website hosting with comprehensive security, performance, and operational features.

## Features

- **Static Website Hosting**: Configured with customizable index and error documents
- **Security**: 
  - CloudFront Origin Access Identity (OAI) support for secure CloudFront integration
  - Public access controls with flexible configuration
  - Server-side encryption with AWS managed keys
- **Performance**: 
  - CORS configuration for API integration
  - Compression and caching optimizations
- **Operational Excellence**:
  - Versioning for data protection
  - Lifecycle management for cost optimization
  - Optional access logging
  - EventBridge notifications for monitoring
- **Environment Awareness**: Production-specific security and performance configurations

## Usage

### Basic Usage

```hcl
module "static_website" {
  source = "../../modules/s3-static-hosting"

  bucket_name = "my-website-${var.environment}"
  environment = var.environment
  
  tags = {
    Environment = var.environment
    Service     = "my-service"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Usage with CloudFront Integration

```hcl
# First create the CloudFront OAI
resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "OAI for ${var.bucket_name}"
}

module "static_website" {
  source = "../../modules/s3-static-hosting"

  bucket_name       = "my-website-${var.environment}"
  environment       = var.environment
  cloudfront_oai_arn = aws_cloudfront_origin_access_identity.website.iam_arn
  
  # Custom CORS configuration
  cors_allowed_origins = [
    "https://mydomain.com",
    "https://api.mydomain.com"
  ]
  cors_allowed_methods = ["GET", "POST", "OPTIONS"]
  
  # Custom document settings
  index_document = "app.html"
  error_document = "404.html"
  
  # Enable advanced features
  enable_versioning = true
  enable_encryption = true
  enable_lifecycle_management = true
  enable_notifications = true
  
  # Optional access logging
  access_log_bucket = "my-access-logs-bucket"
  
  tags = local.common_tags
}
```

### Production Configuration Example

```hcl
module "static_website" {
  source = "../../modules/s3-static-hosting"

  bucket_name = "my-website-prod"
  environment = "prod"
  
  # CloudFront integration for production
  cloudfront_oai_arn = aws_cloudfront_origin_access_identity.website.iam_arn
  
  # Restrictive CORS for production
  cors_allowed_origins = [
    "https://myapp.com",
    "https://www.myapp.com"
  ]
  cors_allowed_methods = ["GET", "POST"]
  cors_allowed_headers = ["Authorization", "Content-Type"]
  cors_max_age_seconds = 86400
  
  # Security hardening
  enable_versioning = true
  enable_encryption = true
  
  # Disable lifecycle management in production (optional)
  enable_lifecycle_management = false
  
  tags = local.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Resources

This module creates the following AWS resources:

- `aws_s3_bucket` - The main S3 bucket for static hosting
- `aws_s3_bucket_website_configuration` - Static website hosting configuration
- `aws_s3_bucket_versioning` - Versioning configuration
- `aws_s3_bucket_server_side_encryption_configuration` - Encryption configuration
- `aws_s3_bucket_public_access_block` - Public access controls
- `aws_s3_bucket_policy` - Bucket policy for OAI or public access
- `aws_s3_bucket_cors_configuration` - CORS configuration
- `aws_s3_bucket_lifecycle_configuration` - Lifecycle management (conditional)
- `aws_s3_bucket_logging` - Access logging (conditional)
- `aws_s3_bucket_notification` - EventBridge notifications (conditional)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | Name of the S3 bucket for static website hosting | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| enable_versioning | Enable S3 bucket versioning | `bool` | `true` | no |
| enable_encryption | Enable server-side encryption with AWS managed keys | `bool` | `true` | no |
| index_document | Index document for the static website | `string` | `"index.html"` | no |
| error_document | Error document for the static website | `string` | `"error.html"` | no |
| cloudfront_oai_arn | CloudFront Origin Access Identity ARN for secure access | `string` | `null` | no |
| cors_allowed_origins | List of allowed origins for CORS requests | `list(string)` | `["*"]` | no |
| cors_allowed_methods | List of allowed HTTP methods for CORS requests | `list(string)` | `["GET", "POST", "PUT", "DELETE", "HEAD"]` | no |
| cors_allowed_headers | List of allowed headers for CORS requests | `list(string)` | `["*"]` | no |
| cors_max_age_seconds | Maximum age for CORS preflight requests in seconds | `number` | `3000` | no |
| enable_lifecycle_management | Enable lifecycle management for cost optimization | `bool` | `true` | no |
| old_version_expiration_days | Number of days after which old object versions are deleted | `number` | `30` | no |
| multipart_upload_cleanup_days | Number of days after which incomplete multipart uploads are cleaned up | `number` | `7` | no |
| access_log_bucket | S3 bucket name for access logs | `string` | `null` | no |
| enable_notifications | Enable S3 event notifications to EventBridge | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | ID of the S3 bucket |
| bucket_arn | ARN of the S3 bucket |
| bucket_name | Name of the S3 bucket |
| website_endpoint | Website endpoint URL |
| website_domain | Website domain name |
| bucket_regional_domain_name | Regional domain name of the bucket |
| bucket_domain_name | Domain name of the bucket |
| hosted_zone_id | Route 53 hosted zone ID of the bucket |
| website_url | Full website URL (HTTP) |
| s3_origin_config | S3 origin configuration for CloudFront |
| bucket_encryption | Bucket encryption configuration |
| bucket_versioning | Bucket versioning configuration |
| public_access_block | Public access block configuration |
| bucket_logging_enabled | Whether bucket logging is enabled |
| eventbridge_notifications_enabled | Whether EventBridge notifications are enabled |

## Security Considerations

1. **CloudFront Integration**: When `cloudfront_oai_arn` is provided, the bucket will be configured for secure CloudFront access only
2. **Public Access**: Without CloudFront OAI, the bucket will have public read access for direct website hosting
3. **CORS Configuration**: Customize CORS settings based on your application's needs
4. **Encryption**: Server-side encryption is enabled by default using AWS managed keys
5. **Versioning**: Enabled by default for data protection
6. **Lifecycle Management**: Automatically cleans up old versions and incomplete uploads to reduce costs

## Cost Optimization

- **Lifecycle Management**: Automatically removes old versions and incomplete multipart uploads
- **Environment-aware**: Different configurations for dev/staging vs production
- **Logging**: Access logging is optional to avoid additional costs
- **Notifications**: EventBridge notifications are disabled by default

## Integration with Other Modules

This module is designed to work seamlessly with:

- **CloudFront Module**: Use the `s3_origin_config` output for CloudFront distribution configuration
- **Route 53**: Use the `hosted_zone_id` and domain name outputs for DNS configuration
- **Monitoring Module**: Bucket metrics and alarms can be integrated for operational visibility

## Examples

See the `examples/` directory (if created) for complete working examples of different use cases.