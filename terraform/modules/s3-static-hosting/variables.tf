variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.bucket_name))
    error_message = "Bucket name must contain only lowercase letters, numbers, hyphens, and periods."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (if not provided, uses AWS managed keys)"
  type        = string
  default     = null
}

variable "index_document" {
  description = "Index document for the static website"
  type        = string
  default     = "index.html"
  validation {
    condition     = can(regex(".*\\.html?$", var.index_document))
    error_message = "Index document must be an HTML file."
  }
}

variable "error_document" {
  description = "Error document for the static website"
  type        = string
  default     = "error.html"
  validation {
    condition     = can(regex(".*\\.html?$", var.error_document))
    error_message = "Error document must be an HTML file."
  }
}

variable "cloudfront_oai_arn" {
  description = "CloudFront Origin Access Identity ARN for secure access (optional)"
  type        = string
  default     = null
  validation {
    condition     = var.cloudfront_oai_arn == null || can(regex("^arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity [A-Z0-9]+$", var.cloudfront_oai_arn))
    error_message = "CloudFront OAI ARN must be a valid CloudFront Origin Access Identity ARN."
  }
}

# Optional variables for advanced configuration
variable "access_log_bucket" {
  description = "S3 bucket name for access logs (optional)"
  type        = string
  default     = null
}

variable "enable_notifications" {
  description = "Enable S3 event notifications to EventBridge"
  type        = bool
  default     = false
}

# CORS configuration
variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS requests"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "List of allowed HTTP methods for CORS requests"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "HEAD"]
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS requests"
  type        = list(string)
  default     = ["*"]
}

variable "cors_max_age_seconds" {
  description = "Maximum age for CORS preflight requests in seconds"
  type        = number
  default     = 3000
  validation {
    condition     = var.cors_max_age_seconds >= 0 && var.cors_max_age_seconds <= 86400
    error_message = "CORS max age must be between 0 and 86400 seconds."
  }
}

# Lifecycle management
variable "enable_lifecycle_management" {
  description = "Enable lifecycle management for cost optimization"
  type        = bool
  default     = true
}

variable "old_version_expiration_days" {
  description = "Number of days after which old object versions are deleted"
  type        = number
  default     = 30
  validation {
    condition     = var.old_version_expiration_days > 0
    error_message = "Old version expiration days must be greater than 0."
  }
}

variable "multipart_upload_cleanup_days" {
  description = "Number of days after which incomplete multipart uploads are cleaned up"
  type        = number
  default     = 7
  validation {
    condition     = var.multipart_upload_cleanup_days > 0
    error_message = "Multipart upload cleanup days must be greater than 0."
  }
}