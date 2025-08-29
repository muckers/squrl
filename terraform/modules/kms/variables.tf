# Variables for KMS encryption module

# ========================================
# Basic Configuration
# ========================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "squrl-"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix can only contain alphanumeric characters and hyphens."
  }
}

variable "name_suffix" {
  description = "Suffix for resource names"
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "Name suffix can only contain alphanumeric characters and hyphens."
  }
}

variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

# ========================================
# Service-Specific Key Enablement
# ========================================

variable "enable_dynamodb_key" {
  description = "Enable dedicated KMS key for DynamoDB encryption"
  type        = bool
  default     = true
}

variable "enable_s3_key" {
  description = "Enable dedicated KMS key for S3 encryption"
  type        = bool
  default     = true
}

variable "enable_lambda_key" {
  description = "Enable dedicated KMS key for Lambda encryption"
  type        = bool
  default     = true
}

variable "enable_secrets_manager_key" {
  description = "Enable dedicated KMS key for Secrets Manager encryption"
  type        = bool
  default     = true
}

variable "enable_parameter_store_key" {
  description = "Enable dedicated KMS key for Parameter Store (SSM) encryption"
  type        = bool
  default     = true
}

variable "enable_kinesis_key" {
  description = "Enable dedicated KMS key for Kinesis encryption"
  type        = bool
  default     = true
}

variable "enable_logs_key" {
  description = "Enable dedicated KMS key for CloudWatch Logs encryption"
  type        = bool
  default     = false
}

# ========================================
# Key Configuration
# ========================================

variable "enable_key_rotation" {
  description = "Enable automatic key rotation for all KMS keys"
  type        = bool
  default     = true
}

variable "key_deletion_window" {
  description = "The waiting period, specified in number of days (7-30)"
  type        = number
  default     = 7
  validation {
    condition     = var.key_deletion_window >= 7 && var.key_deletion_window <= 30
    error_message = "Key deletion window must be between 7 and 30 days."
  }
}

variable "key_usage" {
  description = "Specifies the intended use of the key"
  type        = string
  default     = "ENCRYPT_DECRYPT"
  validation {
    condition = contains([
      "ENCRYPT_DECRYPT",
      "SIGN_VERIFY"
    ], var.key_usage)
    error_message = "Key usage must be ENCRYPT_DECRYPT or SIGN_VERIFY."
  }
}

variable "key_spec" {
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  validation {
    condition = contains([
      "SYMMETRIC_DEFAULT",
      "RSA_2048",
      "RSA_3072",
      "RSA_4096",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
      "ECC_SECG_P256K1"
    ], var.key_spec)
    error_message = "Invalid key spec provided."
  }
}

# ========================================
# Multi-Region Configuration
# ========================================

variable "enable_multi_region" {
  description = "Enable multi-region key replication"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "Map of replica regions for multi-region keys"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "us-west-2" = "us-west-2",
  #   "eu-west-1" = "eu-west-1"
  # }
}

variable "multi_region_key_id" {
  description = "Existing multi-region key ID to use instead of creating new keys"
  type        = string
  default     = null
}

# ========================================
# Advanced Security Settings
# ========================================

variable "key_administrators" {
  description = "List of IAM ARNs that can administer the KMS keys"
  type        = list(string)
  default     = []
}

variable "key_users" {
  description = "List of IAM ARNs that can use the KMS keys"
  type        = list(string)
  default     = []
}

variable "cross_account_access" {
  description = "Map of external AWS account IDs and their allowed actions on keys"
  type = map(object({
    account_id = string
    actions    = list(string)
  }))
  default = {}
}

# ========================================
# Service-Specific Configurations
# ========================================

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs that can use the DynamoDB KMS key"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that can use the S3 KMS key"
  type        = list(string)
  default     = []
}

variable "lambda_function_arns" {
  description = "List of Lambda function ARNs that can use the Lambda KMS key"
  type        = list(string)
  default     = []
}

variable "kinesis_stream_arns" {
  description = "List of Kinesis stream ARNs that can use the Kinesis KMS key"
  type        = list(string)
  default     = []
}

# ========================================
# Cost Optimization
# ========================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features (may affect security)"
  type        = bool
  default     = false
}

variable "use_aws_managed_keys" {
  description = "Use AWS managed keys instead of customer managed keys for cost savings"
  type        = bool
  default     = false
}

# ========================================
# Monitoring and Alerting
# ========================================

variable "enable_key_usage_monitoring" {
  description = "Enable CloudWatch monitoring for key usage"
  type        = bool
  default     = true
}

variable "key_usage_alarm_threshold" {
  description = "Threshold for key usage alarms (requests per minute)"
  type        = number
  default     = 1000
}

variable "enable_key_access_logging" {
  description = "Enable CloudTrail logging for key access events"
  type        = bool
  default     = true
}

# ========================================
# Compliance and Governance
# ========================================

variable "compliance_standards" {
  description = "List of compliance standards this deployment must meet"
  type        = list(string)
  default     = []
  # Example: ["SOX", "HIPAA", "PCI-DSS", "GDPR"]
}

variable "data_classification" {
  description = "Data classification level for the keys"
  type        = string
  default     = "internal"
  validation {
    condition = contains([
      "public",
      "internal",
      "confidential",
      "restricted"
    ], var.data_classification)
    error_message = "Data classification must be one of: public, internal, confidential, restricted."
  }
}

variable "enable_access_analysis" {
  description = "Enable IAM Access Analyzer for key policies"
  type        = bool
  default     = true
}

# ========================================
# Backup and Recovery
# ========================================

variable "enable_backup_keys" {
  description = "Create backup keys in different regions"
  type        = bool
  default     = false
}

variable "backup_key_regions" {
  description = "List of regions to create backup keys"
  type        = list(string)
  default     = []
}

variable "key_recovery_contact" {
  description = "Email address for key recovery notifications"
  type        = string
  default     = ""
  validation {
    condition     = var.key_recovery_contact == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.key_recovery_contact))
    error_message = "Key recovery contact must be a valid email address or empty."
  }
}