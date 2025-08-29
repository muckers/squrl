# AWS Systems Manager Parameter Store Terraform Module

This Terraform module creates and manages AWS Systems Manager (SSM) Parameter Store parameters with a hierarchical structure, IAM policies for access control, and optional resource organization features.

## Features

- **Hierarchical Parameter Structure**: Uses `/{environment}/{app}/{parameter}` pattern for organized parameter management
- **Multiple Parameter Types**: Support for String, StringList, and SecureString parameters
- **IAM Policy Management**: Automatic creation of read/write policies with least-privilege access
- **KMS Encryption**: Built-in support for encrypting SecureString parameters
- **Resource Organization**: Optional resource groups for logical parameter organization
- **Feature Flags**: Built-in support for environment-specific feature flags
- **Base Configuration**: Automatic creation of base configuration parameters
- **Logging & Monitoring**: Optional CloudWatch logging for parameter access
- **Parameter Validation**: Built-in validation rules for parameter values
- **Version Management**: Support for parameter versioning

## Usage

### Basic Example

```hcl
module "parameter_store" {
  source = "../../modules/parameter-store"

  environment = "dev"
  app_name    = "squrl"

  parameters = {
    database_url = {
      value       = "postgresql://localhost:5432/squrl_dev"
      type        = "SecureString"
      description = "Database connection URL"
      tier        = "Standard"
    }
    
    api_base_url = {
      value       = "https://api.dev.squrl.pub"
      type        = "String"
      description = "Base URL for API endpoints"
    }
    
    allowed_origins = {
      value       = "https://dev.squrl.pub,https://localhost:3000"
      type        = "StringList"
      description = "Comma-separated list of allowed CORS origins"
    }
  }

  feature_flags = {
    enable_analytics    = true
    enable_rate_limiting = false
    enable_custom_domains = true
  }

  tags = {
    Environment = "dev"
    Service     = "squrl"
    ManagedBy   = "terraform"
  }
}
```

### Integration with Lambda Functions

```hcl
# Use the parameter store module
module "parameter_store" {
  source = "../../modules/parameter-store"
  
  environment = var.environment
  app_name    = "squrl"
  
  parameters = {
    short_url_base = {
      value       = "https://${var.environment}.squrl.pub"
      type        = "String"
      description = "Base URL for generated short URLs"
    }
    
    jwt_secret = {
      value       = random_password.jwt_secret.result
      type        = "SecureString"
      description = "JWT signing secret"
    }
    
    max_url_length = {
      value       = "2048"
      type        = "String"
      description = "Maximum allowed URL length"
    }
  }
  
  create_write_policy = true  # For CI/CD to update parameters
  
  tags = local.common_tags
}

# Update Lambda function to use parameter store
module "lambda_function" {
  source = "../lambda"
  
  # ... other configuration ...
  
  # Attach the parameter read policy
  additional_policies = [
    module.parameter_store.parameter_read_policy_arn
  ]
  
  # Add environment variables for parameter access
  additional_env_vars = merge(
    var.additional_env_vars,
    module.parameter_store.lambda_environment_variables
  )
}

# Grant Lambda permission to read parameters
resource "aws_iam_role_policy_attachment" "lambda_parameter_access" {
  role       = module.lambda_function.execution_role_name
  policy_arn = module.parameter_store.parameter_read_policy_arn
}
```

### Advanced Configuration with Custom KMS Key

```hcl
# Create custom KMS key for parameter encryption
resource "aws_kms_key" "parameter_store" {
  description             = "KMS key for ${var.app_name} parameter store encryption"
  deletion_window_in_days = 7

  tags = local.common_tags
}

resource "aws_kms_alias" "parameter_store" {
  name          = "alias/${var.app_name}-${var.environment}-parameters"
  target_key_id = aws_kms_key.parameter_store.key_id
}

module "parameter_store" {
  source = "../../modules/parameter-store"

  environment = var.environment
  app_name    = var.app_name

  # Use custom KMS key
  default_kms_key_id = aws_kms_key.parameter_store.arn

  parameters = {
    database_password = {
      value       = random_password.db_password.result
      type        = "SecureString"
      description = "Database password"
      tier        = "Advanced"  # For parameters > 4KB
    }
    
    api_keys = {
      value       = jsonencode({
        github  = var.github_api_key
        stripe  = var.stripe_api_key
        sendgrid = var.sendgrid_api_key
      })
      type        = "SecureString"
      description = "External API keys (JSON)"
    }
  }

  # Enable advanced features
  create_parameter_group     = true
  enable_parameter_logging   = true
  log_retention_days        = 30
  
  # Notification configuration
  notification_config = {
    enabled           = true
    sns_topic_arn     = aws_sns_topic.parameter_changes.arn
    notification_type = "All"
  }

  tags = local.common_tags
}
```

### Complete Integration Example

```hcl
# terraform/environments/dev/main.tf

locals {
  app_config = {
    short_url_base     = "https://staging.squrl.pub"
    max_url_length     = "2048"
    default_expiry_days = "365"
    rate_limit_per_ip   = "100"
    enable_analytics    = "true"
  }
  
  secure_config = {
    jwt_secret = random_password.jwt_secret.result
    db_encryption_key = random_password.db_key.result
  }
  
  feature_flags = {
    enable_custom_domains = true
    enable_abuse_detection = false
    enable_premium_features = false
  }
}

# Parameter Store Module
module "parameter_store" {
  source = "../../modules/parameter-store"

  environment = var.environment
  app_name    = "squrl"

  # Application configuration parameters
  parameters = merge(
    # Convert string values to parameter objects
    { for k, v in local.app_config : k => {
      value       = v
      type        = "String"
      description = "Application configuration: ${k}"
    }},
    
    # Secure parameters
    { for k, v in local.secure_config : k => {
      value       = v
      type        = "SecureString"
      description = "Secure configuration: ${k}"
    }}
  )

  # Feature flags
  feature_flags = local.feature_flags

  # Enable all features for comprehensive setup
  create_write_policy        = true
  create_parameter_group     = true
  enable_parameter_logging   = true
  create_base_config        = true

  tags = local.common_tags
}

# Update existing Lambda functions to use parameters
module "create_url_lambda" {
  source = "../../modules/lambda"

  function_name       = "squrl-create-url-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/create-url/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  
  # Add parameter store access
  additional_policies = [
    module.parameter_store.parameter_read_policy_arn
  ]
  
  additional_env_vars = merge({
    # Traditional environment variables for backwards compatibility
    SHORT_URL_BASE = local.app_config.short_url_base
  }, module.parameter_store.lambda_environment_variables)

  tags = local.common_tags
}
```

## Parameter Hierarchy

This module creates parameters with the following structure:

```
/{environment}/{app_name}/
├── config/
│   └── base                    # Base configuration (if enabled)
├── features/
│   ├── {feature_flag_1}       # Feature flags
│   └── {feature_flag_2}
├── {parameter_1}              # Custom parameters
├── {parameter_2}
└── {parameter_n}
```

### Example Parameter Paths

For `environment = "dev"` and `app_name = "squrl"`:

- `/dev/squrl/short_url_base`
- `/dev/squrl/database_url`
- `/dev/squrl/config/base`
- `/dev/squrl/features/enable_analytics`

## Accessing Parameters in Applications

### Rust Lambda Functions

```rust
use aws_sdk_ssm::Client as SsmClient;
use serde_json::Value;

pub struct ParameterStore {
    client: SsmClient,
    path_prefix: String,
}

impl ParameterStore {
    pub fn new(client: SsmClient, environment: &str, app_name: &str) -> Self {
        Self {
            client,
            path_prefix: format!("/{}/{}", environment, app_name),
        }
    }
    
    pub async fn get_parameter(&self, name: &str) -> Result<String, Box<dyn std::error::Error>> {
        let parameter_name = format!("{}/{}", self.path_prefix, name);
        
        let result = self.client
            .get_parameter()
            .name(parameter_name)
            .with_decryption(true)
            .send()
            .await?;
            
        Ok(result.parameter().unwrap().value().unwrap().to_string())
    }
    
    pub async fn get_parameters_by_path(&self, path: &str) -> Result<Vec<(String, String)>, Box<dyn std::error::Error>> {
        let full_path = format!("{}/{}", self.path_prefix, path);
        
        let result = self.client
            .get_parameters_by_path()
            .path(full_path)
            .with_decryption(true)
            .recursive(true)
            .send()
            .await?;
            
        let parameters = result.parameters()
            .iter()
            .map(|p| (p.name().unwrap().to_string(), p.value().unwrap().to_string()))
            .collect();
            
        Ok(parameters)
    }
    
    // Get all feature flags
    pub async fn get_feature_flags(&self) -> Result<std::collections::HashMap<String, bool>, Box<dyn std::error::Error>> {
        let flags = self.get_parameters_by_path("features").await?;
        let mut feature_flags = std::collections::HashMap::new();
        
        for (name, value) in flags {
            let flag_name = name.split('/').last().unwrap();
            let flag_value = value.parse::<bool>().unwrap_or(false);
            feature_flags.insert(flag_name.to_string(), flag_value);
        }
        
        Ok(feature_flags)
    }
}

// Usage in Lambda function
#[tokio::main]
async fn main() -> Result<(), lambda_runtime::Error> {
    let config = aws_config::load_from_env().await;
    let ssm_client = SsmClient::new(&config);
    
    let environment = std::env::var("ENVIRONMENT").unwrap_or_else(|_| "dev".to_string());
    let app_name = std::env::var("APP_NAME").unwrap_or_else(|_| "squrl".to_string());
    
    let parameter_store = ParameterStore::new(ssm_client, &environment, &app_name);
    
    // Get configuration parameters
    let short_url_base = parameter_store.get_parameter("short_url_base").await?;
    let max_url_length: u32 = parameter_store.get_parameter("max_url_length").await?.parse()?;
    
    // Get feature flags
    let feature_flags = parameter_store.get_feature_flags().await?;
    let analytics_enabled = feature_flags.get("enable_analytics").unwrap_or(&false);
    
    // Use parameters in your application logic
    println!("Short URL base: {}", short_url_base);
    println!("Analytics enabled: {}", analytics_enabled);
    
    Ok(())
}
```

## IAM Permissions

The module creates two IAM policies:

### Read Policy (Always Created)
- `ssm:GetParameter`
- `ssm:GetParameters` 
- `ssm:GetParametersByPath`
- `kms:Decrypt` (for SecureString parameters)

### Write Policy (Optional)
- All read permissions plus:
- `ssm:PutParameter`
- `ssm:DeleteParameter`
- `kms:Encrypt`, `kms:ReEncrypt*`, `kms:GenerateDataKey*` (for SecureString parameters)

## Best Practices

### 1. Parameter Organization
- Use consistent naming conventions
- Group related parameters logically
- Use the hierarchical structure effectively

### 2. Security
- Use SecureString for sensitive data
- Implement least-privilege IAM policies
- Use custom KMS keys for additional security
- Enable parameter access logging in production

### 3. Parameter Types
- **String**: Configuration values, URLs, simple settings
- **StringList**: Comma-separated lists (CORS origins, allowed IPs)
- **SecureString**: Passwords, API keys, certificates

### 4. Environment Management
- Use environment-specific parameter values
- Implement parameter validation
- Use feature flags for environment-specific features

### 5. Monitoring and Alerting
- Enable CloudWatch logging
- Set up SNS notifications for parameter changes
- Monitor parameter access patterns

### 6. Version Management
- Enable parameter versioning for critical parameters
- Implement rollback procedures
- Document parameter change procedures

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure IAM roles have the correct policies attached
   - Verify KMS permissions for SecureString parameters
   - Check parameter name spelling and case sensitivity

2. **Parameter Not Found**
   - Verify the parameter path structure
   - Check that parameters are created in the correct environment
   - Ensure parameter names match exactly

3. **KMS Decryption Errors**
   - Verify KMS key permissions
   - Ensure the correct KMS key is specified
   - Check that the `kms:ViaService` condition is met

4. **Lambda Timeout Issues**
   - Use parameter caching to reduce SSM API calls
   - Consider using GetParametersByPath for bulk retrieval
   - Implement exponential backoff for retries

### Debugging Commands

```bash
# List parameters
aws ssm get-parameters-by-path --path "/dev/squrl" --recursive

# Get specific parameter
aws ssm get-parameter --name "/dev/squrl/short_url_base" --with-decryption

# Check IAM policy simulation
aws iam simulate-principal-policy --policy-source-arn ROLE_ARN --action-names ssm:GetParameter --resource-arns PARAMETER_ARN
```

## Migration from Environment Variables

When migrating from environment variables to Parameter Store:

1. **Phase 1**: Add Parameter Store alongside existing environment variables
2. **Phase 2**: Update application code to prefer Parameter Store values
3. **Phase 3**: Remove environment variables and use Parameter Store exclusively

Example migration code:

```rust
fn get_config_value(param_store: &ParameterStore, param_name: &str, env_var: &str) -> String {
    // Try Parameter Store first, fall back to environment variable
    param_store.get_parameter(param_name).await
        .unwrap_or_else(|_| std::env::var(env_var).unwrap_or_default())
}
```

## Module Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | - | Environment name (dev, staging, prod) |
| `app_name` | string | - | Application name for parameter paths |
| `parameters` | map(object) | {} | Map of parameters to create |
| `default_kms_key_id` | string | null | KMS key for SecureString encryption |
| `create_write_policy` | bool | false | Whether to create write IAM policy |
| `create_parameter_group` | bool | true | Whether to create resource group |
| `feature_flags` | map(bool) | {} | Feature flags to create |
| `tags` | map(string) | {} | Tags for all resources |

## Module Outputs Reference

| Output | Description |
|--------|-------------|
| `parameter_arns` | Map of parameter names to ARNs |
| `parameter_names` | Map of parameter keys to full paths |
| `parameter_read_policy_arn` | ARN of the read IAM policy |
| `lambda_environment_variables` | Environment variables for Lambda integration |

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Update documentation for new features
3. Add appropriate variable validation
4. Include usage examples
5. Test with different parameter types and configurations

## License

This module follows the same license as the parent project.