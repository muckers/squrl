# VPC Endpoints Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# VPC Configuration
variable "create_vpc" {
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of existing VPC to use (required if create_vpc is false)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

# Subnet Configuration
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (only used if create_vpc is true)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (only used if create_vpc is true and create_nat_gateway is true)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "subnet_ids" {
  description = "List of subnet IDs to use for interface VPC endpoints (required if create_vpc is false)"
  type        = list(string)
  default     = []
}

variable "subnet_tags" {
  description = "Tags to filter existing subnets when using existing VPC"
  type        = map(string)
  default     = {}
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway VPC endpoints (required if create_vpc is false)"
  type        = list(string)
  default     = []
}

# NAT Gateway Configuration
variable "create_nat_gateway" {
  description = "Whether to create NAT gateways for private subnet internet access"
  type        = bool
  default     = false
}

# VPC Endpoint Enablement Flags
variable "enable_dynamodb_endpoint" {
  description = "Enable VPC endpoint for DynamoDB"
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Enable VPC endpoint for S3"
  type        = bool
  default     = true
}

variable "enable_secrets_manager_endpoint" {
  description = "Enable VPC endpoint for Secrets Manager"
  type        = bool
  default     = true
}

variable "enable_parameter_store_endpoint" {
  description = "Enable VPC endpoint for Systems Manager Parameter Store"
  type        = bool
  default     = true
}

variable "enable_kms_endpoint" {
  description = "Enable VPC endpoint for KMS"
  type        = bool
  default     = true
}

variable "enable_kinesis_endpoint" {
  description = "Enable VPC endpoint for Kinesis Data Streams"
  type        = bool
  default     = true
}

variable "enable_lambda_endpoint" {
  description = "Enable VPC endpoint for Lambda (for Lambda-to-Lambda calls)"
  type        = bool
  default     = false
}

variable "enable_logs_endpoint" {
  description = "Enable VPC endpoint for CloudWatch Logs"
  type        = bool
  default     = true
}

# Security Group Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access VPC endpoints (defaults to VPC CIDR)"
  type        = list(string)
  default     = []
}

variable "additional_security_group_rules" {
  description = "Additional security group rules for VPC endpoints"
  type = list(object({
    type            = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    description     = string
  }))
  default = []
}

# VPC Endpoint Policies
variable "custom_dynamodb_policy" {
  description = "Custom policy for DynamoDB VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_s3_policy" {
  description = "Custom policy for S3 VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_secrets_manager_policy" {
  description = "Custom policy for Secrets Manager VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_parameter_store_policy" {
  description = "Custom policy for Parameter Store VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_kms_policy" {
  description = "Custom policy for KMS VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_kinesis_policy" {
  description = "Custom policy for Kinesis VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_lambda_policy" {
  description = "Custom policy for Lambda VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

variable "custom_logs_policy" {
  description = "Custom policy for CloudWatch Logs VPC endpoint (JSON string)"
  type        = string
  default     = ""
}

# DNS Configuration
variable "enable_private_dns" {
  description = "Enable private DNS for interface VPC endpoints"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_endpoint_tags" {
  description = "Additional tags for VPC endpoints"
  type        = map(string)
  default     = {}
}

# Cost Optimization
variable "vpc_endpoint_type_preference" {
  description = "Preference for VPC endpoint types: 'gateway' (cheaper) or 'interface' (more features)"
  type        = string
  default     = "gateway"
  validation {
    condition     = contains(["gateway", "interface"], var.vpc_endpoint_type_preference)
    error_message = "VPC endpoint type preference must be either 'gateway' or 'interface'."
  }
}

# Network ACL Configuration
variable "create_network_acls" {
  description = "Whether to create custom network ACLs for additional security"
  type        = bool
  default     = false
}

variable "private_network_acl_rules" {
  description = "Network ACL rules for private subnets"
  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = [
    {
      rule_number = 100
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
    },
    {
      rule_number = 200
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 1024
      to_port     = 65535
    }
  ]
}

# Flow Logs Configuration
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for monitoring"
  type        = bool
  default     = false
}

variable "flow_logs_destination_type" {
  description = "Destination type for VPC Flow Logs (cloud-watch-logs or s3)"
  type        = string
  default     = "cloud-watch-logs"
  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.flow_logs_destination_type)
    error_message = "Flow logs destination type must be either 'cloud-watch-logs' or 's3'."
  }
}

variable "flow_logs_s3_bucket" {
  description = "S3 bucket for VPC Flow Logs (required if destination type is s3)"
  type        = string
  default     = ""
}

# Lambda VPC Configuration
variable "lambda_vpc_config" {
  description = "Configuration for Lambda functions that will use this VPC"
  type = object({
    create_lambda_security_group = bool
    lambda_ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    }))
    lambda_egress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    }))
  })
  default = {
    create_lambda_security_group = true
    lambda_ingress_rules         = []
    lambda_egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "All outbound traffic"
      }
    ]
  }
}

# Monitoring and Alerting
variable "create_vpc_endpoint_alarms" {
  description = "Whether to create CloudWatch alarms for VPC endpoints"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}