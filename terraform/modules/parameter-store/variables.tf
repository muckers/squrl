# Environment and application configuration
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "app_name" {
  description = "Application name used in parameter paths and resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must contain only lowercase letters, numbers, and hyphens."
  }
}

# Parameter configuration
variable "parameters" {
  description = "Map of parameters to create with their configuration"
  type = map(object({
    value       = string
    type        = string
    description = string
    tier        = optional(string, "Standard")
    key_id      = optional(string, null)
    tags        = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.parameters : contains(["String", "StringList", "SecureString"], v.type)
    ])
    error_message = "Parameter type must be one of: String, StringList, SecureString."
  }

  validation {
    condition = alltrue([
      for k, v in var.parameters : contains(["Standard", "Advanced", "Intelligent-Tiering"], v.tier)
    ])
    error_message = "Parameter tier must be one of: Standard, Advanced, Intelligent-Tiering."
  }

  default = {}
}

# KMS configuration
variable "default_kms_key_id" {
  description = "Default KMS key ID/ARN/alias for encrypting SecureString parameters"
  type        = string
  default     = null
}

variable "default_parameter_tier" {
  description = "Default parameter tier for parameters that don't specify one"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.default_parameter_tier)
    error_message = "Default parameter tier must be one of: Standard, Advanced, Intelligent-Tiering."
  }
}

# IAM policy configuration
variable "create_write_policy" {
  description = "Whether to create IAM policy for writing parameters (useful for CI/CD)"
  type        = bool
  default     = false
}

# Resource organization
variable "create_parameter_group" {
  description = "Whether to create a resource group for organizing parameters"
  type        = bool
  default     = true
}

# Logging and monitoring
variable "enable_parameter_logging" {
  description = "Whether to create CloudWatch log group for parameter access logging"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for parameter access logs"
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be one of the valid CloudWatch retention periods."
  }
}

# Base configuration
variable "create_base_config" {
  description = "Whether to create a base configuration parameter with common app metadata"
  type        = bool
  default     = true
}

# Feature flags
variable "feature_flags" {
  description = "Map of feature flags to create as parameters"
  type        = map(bool)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.feature_flags : can(regex("^[a-z0-9_-]+$", k))
    ])
    error_message = "Feature flag names must contain only lowercase letters, numbers, underscores, and hyphens."
  }
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

# Advanced configuration options
variable "parameter_name_prefix" {
  description = "Additional prefix to add to parameter names (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.parameter_name_prefix == "" || can(regex("^[a-zA-Z0-9._-]+$", var.parameter_name_prefix))
    error_message = "Parameter name prefix must contain only alphanumeric characters, periods, underscores, and hyphens."
  }
}

variable "enable_parameter_policies" {
  description = "Whether to enable parameter policies for advanced management"
  type        = bool
  default     = false
}

variable "parameter_policies" {
  description = "Map of parameter policies to apply to specific parameters"
  type = map(object({
    policy_type    = string
    policy_text    = string
    parameter_name = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.parameter_policies : contains(["Expiration", "ExpirationNotification", "NoChangeNotification"], v.policy_type)
    ])
    error_message = "Parameter policy type must be one of: Expiration, ExpirationNotification, NoChangeNotification."
  }
}

# Notification configuration
variable "notification_config" {
  description = "Configuration for parameter change notifications"
  type = object({
    enabled           = bool
    sns_topic_arn     = optional(string, null)
    notification_type = optional(string, "All")
  })
  default = {
    enabled = false
  }

  validation {
    condition     = var.notification_config.enabled == false || var.notification_config.sns_topic_arn != null
    error_message = "SNS topic ARN must be provided when notifications are enabled."
  }

  validation {
    condition     = contains(["All", "Create", "Update", "Delete"], var.notification_config.notification_type)
    error_message = "Notification type must be one of: All, Create, Update, Delete."
  }
}

# Validation rules
variable "parameter_validation" {
  description = "Enable validation rules for parameter values"
  type        = bool
  default     = false
}

variable "validation_rules" {
  description = "Map of validation rules for parameters"
  type = map(object({
    parameter_name  = string
    allowed_pattern = optional(string, null)
    min_length      = optional(number, null)
    max_length      = optional(number, null)
    allowed_values  = optional(list(string), null)
  }))
  default = {}
}

# Backup and versioning
variable "enable_parameter_versioning" {
  description = "Whether to enable parameter versioning (automatically enabled for SecureString)"
  type        = bool
  default     = true
}

variable "max_parameter_versions" {
  description = "Maximum number of parameter versions to keep"
  type        = number
  default     = 5

  validation {
    condition     = var.max_parameter_versions >= 1 && var.max_parameter_versions <= 100
    error_message = "Maximum parameter versions must be between 1 and 100."
  }
}