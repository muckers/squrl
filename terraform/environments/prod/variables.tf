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
  description = "ARN of the ACM certificate for CloudFront HTTPS. Must be in us-east-1 region."
  type        = string
  default     = ""  # Optional: will disable HTTPS if not provided
}