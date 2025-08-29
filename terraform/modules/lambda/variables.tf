variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  type        = string
  default     = ""
}

variable "memory_size" {
  description = "Memory size for the Lambda function"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout for the Lambda function"
  type        = number
  default     = 10
}

variable "rust_log_level" {
  description = "Rust log level"
  type        = string
  default     = "info"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "additional_env_vars" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "kinesis_read_permissions" {
  description = "Whether to grant Kinesis read permissions to the Lambda function"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for Lambda environment variable encryption (optional)"
  type        = string
  default     = null
}

variable "secrets_manager_arns" {
  description = "List of Secrets Manager secret ARNs that the Lambda function needs to access"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  default     = "dev"
}