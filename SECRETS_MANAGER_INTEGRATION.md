# Secrets Manager Integration Guide

## Overview

This document describes the AWS Secrets Manager integration that has been added to the squrl-proto URL shortener application. The integration allows Lambda functions to retrieve configuration from AWS Secrets Manager instead of relying solely on environment variables.

## Key Benefits

- **Enhanced Security**: Sensitive configuration is encrypted at rest using AWS KMS
- **Centralized Configuration**: Manage all environment-specific settings from AWS Secrets Manager
- **Automatic Rotation**: Support for automatic secret rotation
- **Backward Compatibility**: Falls back to environment variables if Secrets Manager is not available
- **Caching**: Built-in caching to reduce API calls and improve performance

## Architecture Changes

### Shared Library Changes

1. **New Module**: `/Users/rjf/code/rust/squrl-proto/shared/src/secrets.rs`
   - `SecretsManagerConfig`: Handles AWS Secrets Manager client operations with caching
   - `AppConfig`: Configuration structure that can be loaded from Secrets Manager or environment variables

2. **Dependencies Added**:
   - `aws-sdk-secretsmanager = "1.86.0"` added to workspace and Lambda function Cargo.toml files
   - `aws-config` added to shared library dependencies

3. **Error Handling**: Added `ConfigurationError` variant to `UrlShortenerError` enum

### Lambda Function Changes

All three Lambda functions have been updated:

#### /Users/rjf/code/rust/squrl-proto/lambda/create-url/src/main.rs
- Updated to use `AppConfig` instead of direct environment variable access
- Added `AppState` struct to hold both database client and application configuration
- Short URL base now comes from configuration instead of hardcoded environment variable

#### /Users/rjf/code/rust/squrl-proto/lambda/redirect/src/main.rs  
- Updated to use `AppConfig` for database and Kinesis configuration
- Kinesis stream name now comes from configuration
- Better error handling when Kinesis is not configured

#### /Users/rjf/code/rust/squrl-proto/lambda/analytics/src/main.rs
- Updated to use `AppConfig` for database configuration
- Prepared for future configuration needs

### Terraform Changes

#### /Users/rjf/code/rust/squrl-proto/terraform/modules/lambda/main.tf
- Added `secrets_manager_access` IAM policy for Lambda functions
- Added `secrets_manager_arns` variable to specify which secrets Lambda functions can access
- Added `ENVIRONMENT` environment variable to help with automatic environment detection
- Enhanced KMS permissions for Secrets Manager integration

#### /Users/rjf/code/rust/squrl-proto/terraform/modules/lambda/variables.tf
- Added `secrets_manager_arns` variable
- Added `environment` variable

## Configuration Structure

### Secrets Manager Secret Format

Secrets should be stored as JSON in AWS Secrets Manager with the following structure:

```json
{
  "dynamodb_table_name": "your-dynamodb-table-name",
  "kinesis_stream_name": "your-kinesis-stream-name", 
  "short_url_base": "https://your-domain.com",
  "rust_log_level": "info",
  "api_keys": {
    "service1": "api-key-1",
    "service2": "api-key-2"
  }
}
```

### Secret Naming Convention

The application automatically detects the environment and looks for secrets named: `{environment}-squrl-config`

For example:
- Development: `dev-squrl-config`  
- Production: `prod-squrl-config`

### Environment Detection

The application detects the environment from these environment variables (in order of preference):
1. `ENVIRONMENT`
2. `ENV` 
3. `STAGE`
4. Defaults to `"dev"` if none are set

## Deployment Instructions

### 1. Create Secrets in AWS Secrets Manager

```bash
# For development environment
aws secretsmanager create-secret \
    --name "dev-squrl-config" \
    --description "Configuration for squrl-proto development environment" \
    --secret-string '{
        "dynamodb_table_name": "dev-squrl-urls",
        "kinesis_stream_name": "dev-squrl-analytics",
        "short_url_base": "https://dev.sqrl.co",
        "rust_log_level": "debug"
    }'

# For production environment  
aws secretsmanager create-secret \
    --name "prod-squrl-config" \
    --description "Configuration for squrl-proto production environment" \
    --secret-string '{
        "dynamodb_table_name": "prod-squrl-urls",
        "kinesis_stream_name": "prod-squrl-analytics", 
        "short_url_base": "https://sqrl.co",
        "rust_log_level": "info"
    }'
```

### 2. Update Terraform Configuration

When deploying Lambda functions, include the Secrets Manager ARNs:

```hcl
module "create_url_lambda" {
  source = "./modules/lambda"
  
  function_name = "squrl-create-url"
  # ... other variables ...
  
  secrets_manager_arns = [
    aws_secretsmanager_secret.app_config.arn
  ]
  environment = var.environment
}
```

### 3. Deploy with Secrets Manager Integration

The application will automatically:
1. Try to load configuration from Secrets Manager first
2. Fall back to environment variables if Secrets Manager is not available
3. Cache secrets for 5 minutes to reduce API calls

## Backward Compatibility

The integration is fully backward compatible:

- If Secrets Manager is not available or configured, the application falls back to environment variables
- All existing environment variable names are supported
- No changes required to existing deployments to continue working

## Environment Variables Supported (Fallback)

| Variable | Purpose | Default |
|----------|---------|---------|
| `DYNAMODB_TABLE_NAME` | DynamoDB table name | `squrl-urls` |
| `KINESIS_STREAM_NAME` | Kinesis stream name | None |
| `SHORT_URL_BASE` | Base URL for short links | `https://sqrl.co` |
| `RUST_LOG` | Logging level | `info` |
| `API_KEY_*` | API keys (format: `API_KEY_NAME=value`) | None |

## Security Considerations

1. **IAM Permissions**: Lambda functions only get access to specific secrets via the `secrets_manager_arns` parameter
2. **KMS Encryption**: Secrets are encrypted using AWS KMS keys
3. **Caching**: Secrets are cached in memory for 5 minutes to balance performance and security
4. **Error Handling**: Secrets Manager failures gracefully fall back to environment variables

## Monitoring and Troubleshooting

### CloudWatch Logs

Look for these log messages:
- `"Loading application configuration..."` - Configuration loading started
- `"Application configuration loaded successfully"` - Configuration loaded from either source
- `"Failed to load from Secrets Manager, falling back to environment variables"` - Fallback occurred

### Common Issues

1. **IAM Permissions**: Ensure Lambda execution role has `secretsmanager:GetSecretValue` permission for the required secrets
2. **Secret Naming**: Verify secret names match the expected pattern: `{environment}-squrl-config`
3. **JSON Format**: Ensure secrets are valid JSON if using Secrets Manager

## Testing

The integration includes comprehensive tests for:
- JSON configuration parsing
- Environment variable fallback
- Secrets Manager client creation
- Configuration defaults

Run tests with:
```bash
cargo test --workspace
```

## Cache Management

The Secrets Manager integration includes a 5-minute cache by default. To customize:

```rust
// Create with custom cache TTL (in seconds)
let secrets_config = SecretsManagerConfig::with_cache_ttl(client, 600); // 10 minutes

// Clear cache manually
secrets_config.clear_cache();
```