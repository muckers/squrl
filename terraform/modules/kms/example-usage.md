# KMS Module Usage Examples

This document provides practical examples of how to use the KMS encryption module in different scenarios.

## Basic Usage Examples

### Example 1: Development Environment

```hcl
module "kms" {
  source = "../../modules/kms"

  environment = "dev"
  
  # Enable only essential keys for cost optimization
  enable_dynamodb_key        = true
  enable_s3_key             = false  # Use AWS managed keys
  enable_lambda_key         = false  # Use AWS managed keys
  enable_secrets_manager_key = false
  enable_parameter_store_key = false
  enable_kinesis_key        = true   # Required for analytics
  enable_logs_key           = false

  # Cost-optimized settings for dev
  enable_key_rotation = false
  key_deletion_window = 7

  tags = {
    Environment = "dev"
    Service     = "squrl"
    ManagedBy   = "terraform"
    CostProfile = "optimized"
  }
}

# Use the KMS key with DynamoDB
module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name  = "squrl-urls-dev"
  environment = "dev"
  kms_key_id  = module.kms.dynamodb_key_arn
  tags        = local.common_tags
}

# Use the KMS key with Kinesis
resource "aws_kinesis_stream" "analytics" {
  name             = "squrl-analytics-dev"
  shard_count      = 1
  retention_period = 24

  encryption_type = "KMS"
  kms_key_id      = module.kms.kinesis_key_id

  tags = local.common_tags
}
```

### Example 2: Production Environment with Full Security

```hcl
module "kms" {
  source = "../../modules/kms"

  environment = "prod"
  
  # Enable all keys for maximum security
  enable_dynamodb_key        = true
  enable_s3_key             = true
  enable_lambda_key         = true
  enable_secrets_manager_key = true
  enable_parameter_store_key = true
  enable_kinesis_key        = true
  enable_logs_key           = true

  # Multi-region configuration for DR
  enable_multi_region = true
  replica_regions = {
    "us-west-2" = "us-west-2"
    "eu-west-1" = "eu-west-1"
  }

  # Production security settings
  enable_key_rotation = true
  key_deletion_window = 30

  # Advanced security configuration
  key_administrators = [
    "arn:aws:iam::123456789012:role/KMSAdminRole"
  ]
  
  key_users = [
    "arn:aws:iam::123456789012:role/ApplicationRole"
  ]

  # Resource-specific access control
  dynamodb_table_arns = [
    "arn:aws:dynamodb:us-east-1:123456789012:table/squrl-urls-prod"
  ]

  # Monitoring and compliance
  enable_key_usage_monitoring = true
  compliance_standards = ["SOX", "GDPR"]
  data_classification  = "confidential"

  tags = {
    Environment     = "prod"
    Service         = "squrl"
    ManagedBy       = "terraform"
    SecurityLevel   = "high"
    Compliance      = "required"
  }
}

# Use with all service modules
module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name  = "squrl-urls-prod"
  environment = "prod"
  kms_key_id  = module.kms.dynamodb_key_arn
  tags        = local.common_tags
}

module "lambda_create_url" {
  source = "../../modules/lambda"

  function_name = "squrl-create-url-prod"
  # ... other configuration
  kms_key_arn   = module.kms.lambda_key_arn
  tags          = local.common_tags
}

module "s3_static_hosting" {
  source = "../../modules/s3-static-hosting"

  bucket_name = "squrl-web-ui-prod"
  environment = "prod"
  kms_key_id  = module.kms.s3_key_id
  tags        = local.common_tags
}

# Attach KMS policies to roles
resource "aws_iam_role_policy_attachment" "lambda_kms" {
  role       = module.lambda_create_url.execution_role_name
  policy_arn = module.kms.lambda_kms_policy_arn
}
```

### Example 3: Integration with Existing Infrastructure

```hcl
# Create KMS keys first
module "kms" {
  source = "../../modules/kms"

  environment = var.environment
  
  enable_dynamodb_key = true
  enable_s3_key       = true
  enable_lambda_key   = true
  enable_kinesis_key  = true
  
  enable_key_rotation = var.environment == "prod"
  key_deletion_window = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

# Then reference in other modules
module "main_infrastructure" {
  source = "./modules/main"

  # Pass KMS key ARNs to the main infrastructure module
  dynamodb_kms_key_arn = module.kms.dynamodb_key_arn
  s3_kms_key_id        = module.kms.s3_key_id
  lambda_kms_key_arn   = module.kms.lambda_key_arn
  kinesis_kms_key_id   = module.kms.kinesis_key_id

  # Other configuration
  environment = var.environment
  tags        = local.common_tags
}
```

## Integration Patterns

### Pattern 1: Conditional KMS Usage

```hcl
locals {
  use_customer_kms = var.environment == "prod"
}

module "kms" {
  count  = local.use_customer_kms ? 1 : 0
  source = "../../modules/kms"

  environment = var.environment
  
  enable_dynamodb_key = true
  enable_s3_key       = true
  enable_lambda_key   = true

  tags = local.common_tags
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = "squrl-urls-${var.environment}"
  environment = var.environment
  
  # Use customer KMS key for prod, AWS managed for dev/staging
  kms_key_id = local.use_customer_kms ? module.kms[0].dynamodb_key_arn : null
  
  tags = local.common_tags
}
```

### Pattern 2: Cross-Environment Key Sharing

```hcl
# Shared KMS keys for non-production environments
module "kms_shared" {
  source = "../../modules/kms"

  environment = "shared"
  
  enable_dynamodb_key = true
  enable_s3_key       = true
  
  # Allow access from multiple accounts/environments
  cross_account_access = {
    dev_account = {
      account_id = "111111111111"
      actions    = ["kms:Decrypt", "kms:GenerateDataKey"]
    }
    staging_account = {
      account_id = "222222222222"
      actions    = ["kms:Decrypt", "kms:GenerateDataKey"]
    }
  }

  tags = {
    Environment = "shared"
    Service     = "squrl"
    ManagedBy   = "terraform"
  }
}
```

### Pattern 3: Service-Specific Key Usage

```hcl
# Different KMS configurations per service
module "kms_data" {
  source = "../../modules/kms"

  environment = var.environment
  name_prefix = "squrl-data-"
  
  # Only data storage keys
  enable_dynamodb_key = true
  enable_s3_key       = true
  enable_kinesis_key  = true
  
  # Stricter settings for data
  enable_key_rotation = true
  key_deletion_window = 30
  data_classification = "confidential"

  tags = merge(local.common_tags, {
    Purpose = "data-encryption"
  })
}

module "kms_compute" {
  source = "../../modules/kms"

  environment = var.environment
  name_prefix = "squrl-compute-"
  
  # Only compute keys
  enable_lambda_key         = true
  enable_secrets_manager_key = true
  enable_parameter_store_key = true
  
  # More relaxed settings for compute
  enable_key_rotation = var.environment == "prod"
  key_deletion_window = var.environment == "prod" ? 14 : 7

  tags = merge(local.common_tags, {
    Purpose = "compute-encryption"
  })
}
```

## Testing and Validation

### Terraform Plan Validation

```bash
# Validate the module syntax
terraform validate

# Plan with different variable combinations
terraform plan -var="environment=dev" -var="enable_key_rotation=false"
terraform plan -var="environment=prod" -var="enable_multi_region=true"
```

### Key Policy Testing

```bash
# Check key policies after deployment
aws kms get-key-policy --key-id alias/squrl-dynamodb-dev --policy-name default

# List all created keys
aws kms list-keys --query 'Keys[?contains(KeyId, `squrl`)]'

# Check key rotation status
aws kms get-key-rotation-status --key-id alias/squrl-dynamodb-dev
```

### Access Testing

```bash
# Test encryption/decryption with the key
aws kms encrypt --key-id alias/squrl-dynamodb-dev --plaintext "test data"
aws kms decrypt --ciphertext-blob <encrypted-data>
```

## Best Practices Implementation

### Environment-Specific Configuration

```hcl
locals {
  kms_config = {
    dev = {
      enable_rotation = false
      deletion_window = 7
      enable_multi_region = false
      cost_optimized = true
    }
    staging = {
      enable_rotation = true
      deletion_window = 14
      enable_multi_region = false
      cost_optimized = false
    }
    prod = {
      enable_rotation = true
      deletion_window = 30
      enable_multi_region = true
      cost_optimized = false
    }
  }
  
  current_config = local.kms_config[var.environment]
}

module "kms" {
  source = "../../modules/kms"

  environment = var.environment
  
  enable_key_rotation = local.current_config.enable_rotation
  key_deletion_window = local.current_config.deletion_window
  enable_multi_region = local.current_config.enable_multi_region
  
  # Enable different keys based on environment
  enable_dynamodb_key        = true
  enable_s3_key             = !local.current_config.cost_optimized
  enable_lambda_key         = !local.current_config.cost_optimized
  enable_secrets_manager_key = var.environment == "prod"
  enable_parameter_store_key = var.environment == "prod"
  enable_kinesis_key        = true
  enable_logs_key           = var.environment == "prod"

  tags = local.common_tags
}
```

### Error Handling

```hcl
# Use try() function for safe key reference
resource "aws_dynamodb_table" "urls" {
  name = "squrl-urls-${var.environment}"
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = try(module.kms.dynamodb_key_arn, null)
  }
}

# Conditional resource creation based on key availability
resource "aws_lambda_function" "example" {
  # ... other configuration
  
  kms_key_arn = var.enable_kms ? module.kms[0].lambda_key_arn : null
  
  depends_on = [
    module.kms
  ]
}
```

## Output Usage Examples

```hcl
# Reference individual keys
output "dynamodb_encryption_key" {
  value = module.kms.dynamodb_key_arn
}

# Reference all keys for external modules
output "kms_keys" {
  value = {
    dynamodb = module.kms.dynamodb_key_arn
    s3       = module.kms.s3_key_arn
    lambda   = module.kms.lambda_key_arn
    kinesis  = module.kms.kinesis_key_arn
  }
}

# Reference policies for IAM attachments
output "kms_policies" {
  value = {
    dynamodb = module.kms.dynamodb_kms_policy_arn
    lambda   = module.kms.lambda_kms_policy_arn
    s3       = module.kms.s3_kms_policy_arn
  }
}

# Full configuration summary
output "kms_summary" {
  value = module.kms.kms_summary
}
```