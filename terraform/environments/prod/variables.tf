variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "admin_email" {
  description = "Administrator email for alerts and notifications"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for CloudFront HTTPS. Must be in us-east-1 region. REQUIRED: Must be provided in secrets.auto.tfvars"
  type        = string
  # No default - this is REQUIRED and must be in secrets.auto.tfvars

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/.+$", var.acm_certificate_arn))
    error_message = "ACM certificate ARN must be valid and in us-east-1 region. Format: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID. Did you create secrets.auto.tfvars?"
  }
}