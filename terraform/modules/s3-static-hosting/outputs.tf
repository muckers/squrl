output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket
}

output "website_endpoint" {
  description = "Website endpoint URL"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_domain" {
  description = "Website domain name"
  value       = aws_s3_bucket_website_configuration.website.website_domain
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "bucket_domain_name" {
  description = "Domain name of the bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID of the bucket"
  value       = aws_s3_bucket.website.hosted_zone_id
}

output "website_url" {
  description = "Full website URL (HTTP)"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

# Outputs useful for CloudFront integration
output "s3_origin_config" {
  description = "S3 origin configuration for CloudFront"
  value = {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.bucket}"
    s3_origin_config = {
      origin_access_identity = var.cloudfront_oai_arn != null ? var.cloudfront_oai_arn : null
    }
  }
}

# Security and compliance outputs
output "bucket_encryption" {
  description = "Bucket encryption configuration"
  value = {
    enabled   = var.enable_encryption
    algorithm = var.enable_encryption ? "AES256" : null
  }
}

output "bucket_versioning" {
  description = "Bucket versioning configuration"
  value = {
    enabled = var.enable_versioning
    status  = aws_s3_bucket_versioning.website.versioning_configuration[0].status
  }
}

output "public_access_block" {
  description = "Public access block configuration"
  value = {
    block_public_acls       = aws_s3_bucket_public_access_block.website.block_public_acls
    block_public_policy     = aws_s3_bucket_public_access_block.website.block_public_policy
    ignore_public_acls      = aws_s3_bucket_public_access_block.website.ignore_public_acls
    restrict_public_buckets = aws_s3_bucket_public_access_block.website.restrict_public_buckets
  }
}

# Monitoring and logging outputs
output "bucket_logging_enabled" {
  description = "Whether bucket logging is enabled"
  value       = var.access_log_bucket != null
}

output "eventbridge_notifications_enabled" {
  description = "Whether EventBridge notifications are enabled"
  value       = var.enable_notifications
}