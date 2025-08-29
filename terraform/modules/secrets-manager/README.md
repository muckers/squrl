# AWS Secrets Manager Terraform Module

A comprehensive Terraform module for managing AWS Secrets Manager secrets with support for automatic rotation, IAM policies, and multi-environment deployments.

## Features

- **Multi-Secret Management**: Create and manage multiple secrets through a single configuration map
- **Automatic Rotation**: Configure automatic secret rotation with Lambda functions
- **Environment-Aware Naming**: Automatically prefix secret names with environment
- **IAM Policy Generation**: Generate IAM policies for Lambda and application access
- **KMS Encryption Support**: Optional customer-managed KMS key encryption
- **Cross-Region Replication**: Support for disaster recovery through cross-region replicas
- **Flexible Configuration**: Support for various secret types and rotation schedules
- **Production Safety**: Environment-specific deletion protection and recovery windows

## Usage

### Basic Example

```hcl
module "secrets_manager" {
  source = "./modules/secrets-manager"

  environment = "dev"
  
  secrets = {
    database_credentials = {
      description = "Database connection credentials"
      secret_value = jsonencode({
        username = "app_user"
        password = "secure_password_123"
        host     = "db.example.com"
        port     = 5432
        database = "myapp"
      })
    }
    
    api_keys = {
      description = "Third-party API keys"
      secret_value = jsonencode({
        stripe_key    = "sk_test_..."
        sendgrid_key  = "SG...."
        analytics_key = "UA-..."
      })
    }
  }

  tags = {
    Project = "squrl-proto"
    Owner   = "platform-team"
  }
}
```

### Advanced Example with Rotation

```hcl
module "secrets_manager" {
  source = "./modules/secrets-manager"

  environment = "prod"
  
  # KMS key for encryption
  kms_key_arn = aws_kms_key.secrets.arn
  
  secrets = {
    database_credentials = {
      description      = "RDS database credentials with automatic rotation"
      rotation_days    = 30
      create_app_policy = true
      secret_value = jsonencode({
        username = "admin"
        password = "initial_password"
        engine   = "postgres"
        host     = aws_rds_cluster.main.endpoint
        port     = 5432
        dbname   = "production"
      })
    }
    
    oauth_tokens = {
      description      = "OAuth tokens for external integrations"
      rotation_days    = 7
      create_app_policy = true
      secret_value = jsonencode({
        client_id     = "oauth_client_id"
        client_secret = "oauth_client_secret"
        refresh_token = "initial_refresh_token"
      })
    }
    
    encryption_keys = {
      description = "Application encryption keys"
      secret_value = jsonencode({
        jwt_secret     = "jwt_signing_key"
        session_secret = "session_encryption_key"
        field_key      = "field_encryption_key"
      })
    }
  }

  # Enhanced configuration
  deletion_protection           = true
  automatic_rotation_enabled    = true
  lambda_rotation_timeout      = 60
  cloudwatch_log_retention_days = 30
  
  # Cross-region replication for disaster recovery
  enable_cross_region_replica = true
  replica_regions            = ["us-east-1", "eu-west-1"]

  tags = {
    Environment = "prod"
    Project     = "squrl-proto"
    Owner       = "platform-team"
    Backup      = "critical"
  }
}
```

### Integration with Lambda Functions

```hcl
# Use the secrets in Lambda functions
module "lambda_function" {
  source = "./modules/lambda"

  function_name = "create-url"
  # ... other lambda configuration
  
  additional_env_vars = {
    DATABASE_SECRET_ARN = module.secrets_manager.secret_arns["database_credentials"]
    API_KEYS_SECRET_ARN = module.secrets_manager.secret_arns["api_keys"]
  }
}

# Attach the secrets read policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_secrets_access" {
  role       = module.lambda_function.lambda_role_name
  policy_arn = module.secrets_manager.lambda_secrets_read_policy_arn
}

# Or use individual app policies for better security
resource "aws_iam_role_policy_attachment" "lambda_db_secrets" {
  role       = module.lambda_function.lambda_role_name  
  policy_arn = module.secrets_manager.app_secrets_read_policy_arns["database_credentials"]
}
```

### Environment-Specific Configuration

```hcl
# Development environment
module "secrets_manager_dev" {
  source = "./modules/secrets-manager"

  environment = "dev"
  
  secrets = {
    database_credentials = {
      description = "Dev database credentials"
      secret_value = jsonencode({
        username = "dev_user"
        password = "dev_password"
        host     = "dev-db.internal"
        port     = 5432
      })
    }
  }
  
  # Less restrictive settings for development
  deletion_protection = false
  
  tags = {
    Environment = "dev"
    Project     = "squrl-proto"
  }
}

# Production environment
module "secrets_manager_prod" {
  source = "./modules/secrets-manager"

  environment = "prod"
  kms_key_arn = aws_kms_key.prod_secrets.arn
  
  secrets = {
    database_credentials = {
      description      = "Production database credentials"
      rotation_days    = 30
      create_app_policy = true
      secret_value = jsonencode({
        username = "prod_admin"
        password = "secure_prod_password"
        host     = aws_rds_cluster.prod.endpoint
        port     = 5432
      })
    }
  }
  
  # Production safety settings
  deletion_protection           = true
  enable_cross_region_replica   = true
  replica_regions              = ["us-west-2"]
  cloudwatch_log_retention_days = 90
  
  tags = {
    Environment = "prod"
    Project     = "squrl-proto"
    Compliance  = "required"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| secrets | Map of secrets configuration | `map(object)` | n/a | yes |
| kms_key_arn | ARN of KMS key for encryption | `string` | `null` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| enable_cross_region_replica | Enable cross-region replication | `bool` | `false` | no |
| replica_regions | List of replica regions | `list(string)` | `[]` | no |
| deletion_protection | Enable deletion protection | `bool` | `true` | no |
| automatic_rotation_enabled | Enable automatic rotation | `bool` | `true` | no |
| lambda_rotation_timeout | Lambda rotation timeout in seconds | `number` | `30` | no |
| rotation_lambda_memory | Lambda memory allocation in MB | `number` | `128` | no |
| rotation_lambda_runtime | Lambda runtime for rotation functions | `string` | `"python3.9"` | no |
| create_lambda_read_policy | Create general Lambda read policy | `bool` | `true` | no |
| cloudwatch_log_retention_days | CloudWatch log retention days | `number` | `14` | no |

### Secrets Configuration Object

Each secret in the `secrets` map supports the following properties:

| Property | Description | Type | Required |
|----------|-------------|------|----------|
| description | Description of the secret | `string` | yes |
| rotation_days | Days between automatic rotations | `number` | no |
| rotation_lambda_code | Lambda code for rotation | `string` | no |
| secret_value | Initial secret value (JSON string) | `string` | no |
| create_app_policy | Create individual app access policy | `bool` | no |

## Outputs

| Name | Description |
|------|-------------|
| secret_arns | Map of secret names to ARNs |
| secret_names | Map of secret keys to full names |
| secret_ids | Map of secret keys to IDs |
| lambda_secrets_read_policy_arn | ARN of Lambda read policy |
| app_secrets_read_policy_arns | Map of individual app policy ARNs |
| rotation_lambda_function_arn | ARN of rotation Lambda function |
| rotation_lambda_role_arn | ARN of rotation Lambda role |
| secret_arn_pattern | ARN pattern for all secrets |

## Secret Naming Convention

Secrets are automatically named using the pattern: `{environment}-{secret_key}`

Examples:
- `dev-database_credentials`
- `prod-api_keys`
- `staging-oauth_tokens`

## IAM Policies

The module creates several IAM policies:

1. **Lambda Secrets Read Policy**: Allows reading all secrets (general use)
2. **App-Specific Policies**: Individual policies for each secret (fine-grained access)
3. **Rotation Lambda Policy**: Policy for Lambda rotation functions

## Security Best Practices

1. **KMS Encryption**: Always use customer-managed KMS keys in production
2. **Least Privilege**: Use app-specific policies instead of the general Lambda policy when possible
3. **Rotation**: Enable automatic rotation for sensitive credentials
4. **Cross-Region Replication**: Enable for production environments
5. **Deletion Protection**: Always enable for production secrets
6. **Monitoring**: Use CloudWatch logs to monitor secret access

## Lambda Function Integration

To use secrets in your Lambda functions:

### Environment Variables Approach
```hcl
additional_env_vars = {
  DB_SECRET_ARN = module.secrets_manager.secret_arns["database_credentials"]
}
```

### Rust Code Example
```rust
use aws_sdk_secretsmanager::{Client, Error};
use serde_json::Value;

pub async fn get_secret(secret_arn: &str) -> Result<Value, Error> {
    let config = aws_config::load_from_env().await;
    let client = Client::new(&config);
    
    let response = client
        .get_secret_value()
        .secret_id(secret_arn)
        .send()
        .await?;
    
    let secret_string = response.secret_string().unwrap_or("{}");
    let secret_value: Value = serde_json::from_str(secret_string)?;
    
    Ok(secret_value)
}

// Usage in Lambda function
#[tokio::main]
async fn main() -> Result<(), Error> {
    let secret_arn = std::env::var("DB_SECRET_ARN")
        .expect("DB_SECRET_ARN environment variable not set");
    
    let db_config = get_secret(&secret_arn).await?;
    let host = db_config["host"].as_str().unwrap();
    let username = db_config["username"].as_str().unwrap();
    let password = db_config["password"].as_str().unwrap();
    
    // Use the credentials...
    Ok(())
}
```

## Rotation Configuration

For secrets that require automatic rotation, you can specify:

```hcl
secrets = {
  database_password = {
    description      = "Database password with rotation"
    rotation_days    = 30  # Rotate every 30 days
    create_app_policy = true
  }
}
```

## Error Handling

The module includes validation for:
- Environment names (dev, staging, prod)
- Rotation days (1-365)
- KMS ARN format
- Lambda timeout limits
- Memory allocation ranges

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Update variable validation rules
3. Add appropriate output values
4. Update documentation and examples
5. Test with multiple environments

## License

This module is part of the squrl-proto project and follows the same license terms.