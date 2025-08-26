variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "admin_email" {
  description = "Administrator email for alerts and notifications"
  type        = string
  default     = "admin@example.com"
}