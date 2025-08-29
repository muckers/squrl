# KMS Encryption Module

This Terraform module provides comprehensive KMS (Key Management Service) encryption capabilities for the Squrl URL shortener service. It creates dedicated KMS keys for different AWS services with proper access policies, key rotation, and multi-region support.

## Features

- **Service-Specific KMS Keys**: Dedicated keys for DynamoDB, S3, Lambda, Secrets Manager, Parameter Store, Kinesis, and CloudWatch Logs
- **Automatic Key Rotation**: Configurable automatic key rotation for enhanced security
- **Multi-Region Support**: Key replication across multiple AWS regions
- **IAM Integration**: Pre-configured IAM policies for service access
- **Security Best Practices**: Least privilege access and proper key policies
- **Cost Optimization**: Optional cost optimization features
- **Monitoring Ready**: CloudWatch integration for key usage monitoring

## Usage

### Basic Usage

```hcl
module "kms" {
  source = "../../modules/kms"

  environment = "dev"
  
  # Enable keys for specific services
  enable_dynamodb_key        = true
  enable_s3_key             = true
  enable_lambda_key         = true
  enable_secrets_manager_key = true
  enable_parameter_store_key = true
  enable_kinesis_key        = true
  enable_logs_key           = false  # Optional for cost savings

  # Key configuration
  enable_key_rotation   = true
  key_deletion_window   = 7

  tags = {
    Environment = "dev"
    Service     = "squrl"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Configuration with Multi-Region

```hcl
module "kms" {
  source = "../../modules/kms"

  environment = "prod"
  
  # Service keys
  enable_dynamodb_key        = true
  enable_s3_key             = true
  enable_lambda_key         = true
  enable_secrets_manager_key = true
  enable_parameter_store_key = true
  enable_kinesis_key        = true
  enable_logs_key           = true

  # Multi-region configuration
  enable_multi_region = true
  replica_regions = {
    "us-west-2" = "us-west-2"
    "eu-west-1" = "eu-west-1"
  }

  # Security configuration
  enable_key_rotation = true
  key_deletion_window = 30  # Longer window for production

  # Advanced security
  key_administrators = [
    "arn:aws:iam::123456789012:role/KMSAdminRole"
  ]
  key_users = [
    "arn:aws:iam::123456789012:role/ApplicationRole"
  ]

  # Resource-specific access
  dynamodb_table_arns = [
    "arn:aws:dynamodb:us-east-1:123456789012:table/squrl-urls-prod"
  ]
  s3_bucket_arns = [
    "arn:aws:s3:::squrl-web-ui-prod"
  ]

  # Monitoring
  enable_key_usage_monitoring = true
  key_usage_alarm_threshold   = 1000

  # Compliance
  compliance_standards = ["SOX", "GDPR"]
  data_classification  = "confidential"

  tags = {
    Environment = "prod"
    Service     = "squrl"
    ManagedBy   = "terraform"
    Compliance  = "required"
  }
}
```

### Integration with Existing Modules

#### DynamoDB Integration

```hcl
module "kms" {
  source = "../../modules/kms"
  
  environment         = var.environment
  enable_dynamodb_key = true
  
  tags = local.common_tags
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name  = "squrl-urls-${var.environment}"
  environment = var.environment

  # Use KMS key from KMS module
  kms_key_id = module.kms.dynamodb_key_arn

  # Pass through other configuration...
}
```

#### Lambda Integration

```hcl
module "kms" {
  source = "../../modules/kms"
  
  environment       = var.environment
  enable_lambda_key = true
  
  tags = local.common_tags
}

module "lambda" {
  source = "../../modules/lambda"

  function_name = "squrl-create-url-${var.environment}"
  # ... other lambda configuration

  # Use KMS key for environment variables encryption
  kms_key_arn = module.kms.lambda_key_arn

  tags = local.common_tags
}

# Attach KMS policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_kms" {
  role       = module.lambda.execution_role_name
  policy_arn = module.kms.lambda_kms_policy_arn
}
```

#### S3 Integration

```hcl
module "kms" {
  source = "../../modules/kms"
  
  environment   = var.environment
  enable_s3_key = true
  
  tags = local.common_tags
}

module "s3_static_hosting" {
  source = "../../modules/s3-static-hosting"

  bucket_name = "squrl-web-ui-${var.environment}"
  environment = var.environment

  # Use KMS key for S3 encryption
  kms_key_id = module.kms.s3_key_id

  tags = local.common_tags
}
```

### Cost-Optimized Configuration

For development environments where cost is a concern:

```hcl
module "kms" {
  source = "../../modules/kms"

  environment = "dev"
  
  # Enable only essential keys
  enable_dynamodb_key        = true
  enable_s3_key             = false  # Use AWS managed keys
  enable_lambda_key         = false  # Use AWS managed keys
  enable_secrets_manager_key = false
  enable_parameter_store_key = false
  enable_kinesis_key        = true   # Required for analytics
  enable_logs_key           = false  # Use AWS managed keys

  # Cost optimization
  enable_cost_optimization = true
  use_aws_managed_keys    = true

  # Shorter deletion window for dev
  key_deletion_window = 7

  tags = {
    Environment = "dev"
    Service     = "squrl"
    ManagedBy   = "terraform"
    CostProfile = "optimized"
  }
}
```

## Module Inputs

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `environment` | Environment name (dev, staging, prod) | `string` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Prefix for resource names | `string` | `"squrl-"` |
| `name_suffix` | Suffix for resource names | `string` | `""` |
| `tags` | A map of tags to assign to all resources | `map(string)` | `{}` |

### Service Key Enablement

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_dynamodb_key` | Enable dedicated KMS key for DynamoDB | `bool` | `true` |
| `enable_s3_key` | Enable dedicated KMS key for S3 | `bool` | `true` |
| `enable_lambda_key` | Enable dedicated KMS key for Lambda | `bool` | `true` |
| `enable_secrets_manager_key` | Enable dedicated KMS key for Secrets Manager | `bool` | `true` |
| `enable_parameter_store_key` | Enable dedicated KMS key for Parameter Store | `bool` | `true` |
| `enable_kinesis_key` | Enable dedicated KMS key for Kinesis | `bool` | `true` |
| `enable_logs_key` | Enable dedicated KMS key for CloudWatch Logs | `bool` | `false` |

### Key Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_key_rotation` | Enable automatic key rotation | `bool` | `true` |
| `key_deletion_window` | Key deletion window (7-30 days) | `number` | `7` |
| `key_usage` | Key usage type | `string` | `"ENCRYPT_DECRYPT"` |
| `key_spec` | Key specification | `string` | `"SYMMETRIC_DEFAULT"` |

### Multi-Region Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_multi_region` | Enable multi-region key replication | `bool` | `false` |
| `replica_regions` | Map of replica regions | `map(string)` | `{}` |

## Module Outputs

### Service-Specific Outputs

Each service has the following outputs:
- `{service}_key_id` - KMS key ID
- `{service}_key_arn` - KMS key ARN  
- `{service}_key_alias` - KMS key alias name
- `{service}_key_alias_arn` - KMS key alias ARN

### Consolidated Outputs

| Name | Description |
|------|-------------|
| `all_key_ids` | Map of service name to KMS key ID |
| `all_key_arns` | Map of service name to KMS key ARN |
| `all_key_aliases` | Map of service name to KMS key alias |
| `all_key_alias_arns` | Map of service name to KMS key alias ARN |

### IAM Policy Outputs

| Name | Description |
|------|-------------|
| `dynamodb_kms_policy_arn` | ARN of DynamoDB KMS access policy |
| `lambda_kms_policy_arn` | ARN of Lambda KMS access policy |
| `s3_kms_policy_arn` | ARN of S3 KMS access policy |

## Security Considerations

### Key Policies

Each KMS key includes:
- **Root Access**: AWS account root has full access
- **Service Access**: Specific AWS services can use keys via service-linked roles
- **Conditional Access**: Access is restricted to specific service endpoints
- **Cross-Account Protection**: Keys are protected from cross-account access by default

### Access Control

- **Least Privilege**: Each key grants minimum required permissions
- **Service Isolation**: Keys are isolated per AWS service
- **Regional Restrictions**: Keys are restricted to specific AWS regions
- **Resource Restrictions**: Access can be limited to specific resources

### Monitoring

The module supports:
- **CloudWatch Metrics**: Key usage metrics
- **CloudTrail Integration**: API call logging
- **Access Analysis**: IAM Access Analyzer support
- **Cost Monitoring**: Usage and cost tracking

## Best Practices

### Environment-Specific Configuration

- **Development**: Use fewer keys, shorter deletion windows
- **Staging**: Mirror production configuration with relaxed monitoring
- **Production**: Enable all security features, longer deletion windows

### Key Rotation

- **Enable Rotation**: Always enable for production environments
- **Schedule**: AWS automatically rotates keys annually
- **Monitoring**: Monitor rotation status and failures

### Multi-Region Deployments

- **Replica Keys**: Create replica keys in disaster recovery regions
- **Cross-Region Access**: Configure appropriate cross-region policies
- **Failover**: Test key availability during region failover scenarios

### Cost Management

- **Key Consolidation**: Use fewer keys in development environments
- **AWS Managed Keys**: Consider AWS managed keys for non-sensitive data
- **Usage Monitoring**: Monitor key usage to optimize costs

## Troubleshooting

### Common Issues

1. **Access Denied Errors**
   - Check IAM policies are properly attached
   - Verify key policies allow the required actions
   - Ensure correct key ARN is being used

2. **Key Not Found**
   - Verify key is created in the correct region
   - Check if key alias is being used correctly
   - Ensure key hasn't been scheduled for deletion

3. **Multi-Region Issues**
   - Verify replica regions are correctly configured
   - Check cross-region permissions
   - Ensure provider aliases are set up correctly

### Debugging

Enable Terraform debugging:
```bash
export TF_LOG=DEBUG
terraform plan
```

Check AWS KMS service:
```bash
aws kms list-keys
aws kms describe-key --key-id <key-id>
aws kms get-key-policy --key-id <key-id> --policy-name default
```

## Migration

### From AWS Managed Keys

1. Create customer managed keys using this module
2. Update resource configurations to use new keys
3. Re-encrypt existing data with new keys
4. Monitor for any access issues

### Between Regions

1. Enable multi-region support
2. Create replica keys in target regions
3. Update applications to use regional key ARNs
4. Test cross-region failover scenarios

## Contributing

When contributing to this module:

1. **Security First**: Ensure all changes maintain security best practices
2. **Backward Compatibility**: Don't break existing implementations
3. **Documentation**: Update README and examples for any new features
4. **Testing**: Test with different service combinations and regions
5. **Cost Impact**: Document any cost implications of changes

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review AWS KMS documentation
3. Check Terraform AWS provider documentation
4. Open an issue with detailed error messages and configuration