# Variables for AWS Secrets Manager Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "secrets" {
  description = "Map of secrets to create. Each secret can have the following properties: description, rotation_days, rotation_lambda_code, secret_value, create_app_policy"
  type = map(object({
    description          = string
    rotation_days        = optional(number)
    rotation_lambda_code = optional(string)
    secret_value         = optional(string)
    create_app_policy    = optional(bool, false)
  }))

  validation {
    condition     = length(var.secrets) > 0
    error_message = "At least one secret must be defined."
  }

  validation {
    condition = alltrue([
      for k, v in var.secrets :
      v.rotation_days == null || (v.rotation_days >= 1 && v.rotation_days <= 365)
    ])
    error_message = "Rotation days must be between 1 and 365 when specified."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encrypting secrets. If not provided, AWS managed key will be used."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN starting with 'arn:aws:kms:' when provided."
  }
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

variable "enable_cross_region_replica" {
  description = "Enable cross-region replica for disaster recovery"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "List of AWS regions where secret replicas should be created"
  type        = list(string)
  default     = []

  validation {
    condition     = var.enable_cross_region_replica == false || length(var.replica_regions) > 0
    error_message = "At least one replica region must be specified when cross-region replica is enabled."
  }
}

variable "secret_name_prefix" {
  description = "Optional prefix for secret names. If not provided, environment will be used as prefix."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection for secrets in production"
  type        = bool
  default     = true
}

variable "automatic_rotation_enabled" {
  description = "Enable automatic rotation for secrets that support it"
  type        = bool
  default     = true
}

variable "lambda_rotation_timeout" {
  description = "Timeout in seconds for Lambda rotation functions"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_rotation_timeout >= 3 && var.lambda_rotation_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "rotation_lambda_memory" {
  description = "Memory allocation for Lambda rotation functions in MB"
  type        = number
  default     = 128

  validation {
    condition     = var.rotation_lambda_memory >= 128 && var.rotation_lambda_memory <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "rotation_lambda_runtime" {
  description = "Runtime for Lambda rotation functions"
  type        = string
  default     = "python3.9"

  validation {
    condition     = contains(["python3.8", "python3.9", "python3.10", "python3.11", "nodejs16.x", "nodejs18.x"], var.rotation_lambda_runtime)
    error_message = "Lambda runtime must be one of: python3.8, python3.9, python3.10, python3.11, nodejs16.x, nodejs18.x."
  }
}

variable "create_lambda_read_policy" {
  description = "Create a general Lambda read policy for all secrets"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days for Lambda rotation functions"
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_retention_days)
    error_message = "Log retention days must be one of the valid CloudWatch retention periods."
  }
}

variable "secret_description_prefix" {
  description = "Prefix to add to all secret descriptions"
  type        = string
  default     = ""
}

variable "enable_secret_versioning" {
  description = "Enable automatic versioning for secrets"
  type        = bool
  default     = true
}

variable "max_secret_versions" {
  description = "Maximum number of secret versions to retain"
  type        = number
  default     = 100

  validation {
    condition     = var.max_secret_versions >= 1 && var.max_secret_versions <= 100
    error_message = "Maximum secret versions must be between 1 and 100."
  }
}