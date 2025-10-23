# Lambda Module

This Terraform module creates and configures AWS Lambda functions for the Squrl URL shortener service, providing a reusable template for deploying Rust-based Lambda functions with proper IAM permissions and monitoring.

## Features

- **Rust Runtime Support:** Uses `provided.al2` runtime optimized for Rust Lambda functions
- **IAM Role Management:** Automatic creation and configuration of execution roles
- **DynamoDB Integration:** Built-in permissions for DynamoDB operations
- **CloudWatch Logging:** Automatic log group creation with configurable retention
- **Environment Variables:** Flexible configuration through environment variables
- **Resource Tagging:** Consistent tagging for cost tracking and management

## Lambda Functions

This module is used to deploy two core Lambda functions:

1. **create-url:** Creates shortened URLs and stores them in DynamoDB
2. **redirect:** Handles URL redirects and updates click counts

## Usage

### Basic Lambda Function

```hcl
module "create_url_lambda" {
  source = "./modules/lambda"

  function_name       = "squrl-create-url-dev"
  lambda_zip_path     = "./target/lambda/create-url/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn

  memory_size = 256
  timeout     = 10

  tags = {
    Environment = "dev"
    Service     = "squrl"
  }
}
```

### Redirect Lambda Function

```hcl
module "redirect_lambda" {
  source = "./modules/lambda"

  function_name       = "squrl-redirect-dev"
  lambda_zip_path     = "./target/lambda/redirect/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn

  memory_size = 256
  timeout     = 10

  tags = {
    Environment = "dev"
    Service     = "squrl"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | `string` | n/a | yes |
| lambda_zip_path | Path to the Lambda deployment package | `string` | n/a | yes |
| dynamodb_table_name | Name of the DynamoDB table | `string` | n/a | yes |
| dynamodb_table_arn | ARN of the DynamoDB table | `string` | n/a | yes |
| memory_size | Memory size for the Lambda function (MB) | `number` | `256` | no |
| timeout | Timeout for the Lambda function (seconds) | `number` | `10` | no |
| rust_log_level | Rust log level (trace, debug, info, warn, error) | `string` | `"info"` | no |
| log_retention_days | CloudWatch log retention in days | `number` | `14` | no |
| additional_env_vars | Additional environment variables | `map(string)` | `{}` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| invoke_arn | Invoke ARN of the Lambda function (for API Gateway) |

## IAM Permissions

The module automatically creates and attaches the following IAM policies:

### Basic Execution Role
- CloudWatch Logs write permissions
- VPC network interface management (if VPC configured)

### DynamoDB Permissions
- `GetItem` - Read URL data
- `PutItem` - Create new URLs
- `Query` - Query by indexes
- `UpdateItem` - Update click counts

## Environment Variables

The module sets the following environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| DYNAMODB_TABLE_NAME | Name of the DynamoDB table | `squrl-urls-dev` |
| RUST_LOG | Rust logging level | `info` |
| Additional vars | Custom environment variables | As specified |

## Performance Tuning

### Memory Configuration
- **create-url:** 256 MB (lightweight operations)
- **redirect:** 256 MB (simple lookups and updates)

### Timeout Settings
- **create-url:** 10 seconds (includes DynamoDB writes)
- **redirect:** 10 seconds (includes DynamoDB updates)

## Monitoring

### CloudWatch Logs
- Automatic log group creation: `/aws/lambda/{function_name}`
- Configurable retention period (default: 14 days)
- Structured JSON logging with tracing support

### CloudWatch Metrics
- **Invocations:** Total function invocations
- **Errors:** Function errors and failures
- **Duration:** Execution time metrics
- **Throttles:** Rate limiting events
- **ConcurrentExecutions:** Active function instances

## Build Requirements

Lambda functions must be built using cargo-lambda:

```bash
# Install cargo-lambda
pip install cargo-lambda

# Build function
cargo lambda build --release --output-format zip

# Output location
./target/lambda/{function_name}/bootstrap.zip
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Rust Lambda functions built with cargo-lambda
- Appropriate IAM permissions for Lambda and resource creation

## Notes

- The module uses `provided.al2` runtime for optimal Rust performance
- X-Ray tracing has been removed for monitoring simplification
- Functions are stateless and designed for horizontal scaling
- IAM roles are created per function for security isolation
- CloudWatch Logs are the primary debugging and monitoring tool