# Milestone 01: Serverless Foundation
**Phase 1 (Weeks 1-2) - Serverless URL Shortener**

## Overview
This milestone focuses on migrating the existing SQLite-based URL shortener to a serverless architecture using AWS Lambda and DynamoDB. The goal is to establish the core serverless foundation that will support global scale in later phases.

## Technical Architecture

### Current State Analysis
- **Existing Implementation**: Rust application using SQLite with base62 encoding
- **Core Logic**: Sequential ID generation with base62 encoding for short codes
- **Features**: URL deduplication, simple key-value storage

### Target Serverless Architecture
```
┌─────────────────┐    ┌─────────────────┐
│   create-url    │    │    redirect     │
│   Lambda        │    │   Lambda +      │
│                 │    │   Click Track   │
└─────────────────┘    └─────────────────┘
        │                       │
        └───────────────────────┘
                               │
                    ┌─────────────────┐
                    │   DynamoDB      │
                    │   Main Table    │
                    └─────────────────┘
```

## 1. Lambda Function Specifications

### 1.1 create-url Function

**Purpose**: Create shortened URLs with collision-resistant ID generation

**Runtime**: `provided.al2` (Custom Rust runtime)

**Memory**: 256MB (adjustable based on performance testing)

**Timeout**: 10 seconds

**Environment Variables**:
```rust
DYNAMODB_TABLE_NAME: "squrl-urls"
DYNAMODB_REGION: "us-east-1"
RUST_LOG: "info"
```

**Input Format**:
```json
{
  "original_url": "https://example.com/very/long/url",
  "custom_code": "optional-custom-short-code",
  "ttl_hours": 8760
}
```

**Output Format**:
```json
{
  "short_code": "b3xK9mP",
  "original_url": "https://example.com/very/long/url",
  "created_at": "2025-08-23T10:30:00Z",
  "expires_at": "2026-08-23T10:30:00Z"
}
```

**Error Responses**:
```json
{
  "error": "InvalidUrl",
  "message": "The provided URL is not valid"
}
```

### 1.2 redirect Function

**Purpose**: Lookup URLs and perform redirects with click tracking

**Runtime**: `provided.al2` (Custom Rust runtime)

**Memory**: 256MB

**Timeout**: 5 seconds

**Input Format**:
```json
{
  "short_code": "b3xK9mP",
  "client_ip": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "referer": "https://social-media.com"
}
```

**Output Format**:
```json
{
  "original_url": "https://example.com/very/long/url",
  "redirect_type": "301"
}
```

### 1.3 Click Tracking Integration

**Purpose**: Direct click count updates in DynamoDB via redirect function

**Implementation**: Integrated with redirect Lambda function

**Method**: Atomic increment operations on DynamoDB click_count field

**No PII**: Only anonymous click counts tracked, no IP addresses or user data

**Privacy Compliant**: Zero personal data collection

## 2. DynamoDB Schema Design

### 2.1 Main Table: `squrl-urls`

**Primary Key**:
- Partition Key: `short_code` (String) - Base62 encoded short code

**Attributes**:
```rust
{
  "short_code": String,      // Primary key - base62 encoded
  "original_url": String,    // The full URL to redirect to
  "created_at": String,      // ISO 8601 timestamp
  "expires_at": Number,      // Unix timestamp for TTL
  "click_count": Number,     // Total clicks (updated atomically)
  "creator_ip": String,      // IP address of creator (optional)
  "custom_code": Boolean,    // Whether this was a custom short code
  "status": String,          // "active", "expired", "disabled"
}
```

**Global Secondary Index (GSI) - URL Deduplication**:
- Name: `original-url-index`
- Partition Key: `original_url` (String)
- Sort Key: `created_at` (String)
- Projection: `short_code`, `created_at`, `status`

**Table Configuration**:
```rust
BillingMode::OnDemand
DeletionProtection: true
PointInTimeRecovery: true
StreamSpecification: {
    StreamEnabled: true,
    StreamViewType: "NEW_AND_OLD_IMAGES"
}
TimeToLiveSpecification: {
    AttributeName: "expires_at",
    Enabled: true
}
```

### 2.2 Click Tracking (Integrated in URLs Table)

Click tracking is now integrated directly into the main `squrl-urls` table:
- `click_count` field stores total clicks per short code
- Atomic increment operations ensure consistency
- No separate analytics table needed
- No PII collection - only anonymous click counts
- Privacy-compliant design with zero user data storage

## 3. Rust Dependencies and Crates

### 3.1 Cargo.toml Dependencies

```toml
[dependencies]
# Lambda Runtime
lambda_runtime = "0.8"
lambda_web = "0.2"  # For HTTP event handling
tokio = { version = "1.0", features = ["macros", "rt-multi-thread"] }

# AWS SDK
aws-config = "1.0"
aws-sdk-dynamodb = "1.0"
# Click tracking handled directly in DynamoDB via redirect function

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# HTTP and URL handling
url = "2.4"
reqwest = { version = "0.11", features = ["json"] }

# Error handling
thiserror = "1.0"
anyhow = "1.0"

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# Time handling
chrono = { version = "0.4", features = ["serde"] }

# ID generation
nanoid = "0.4"  # Alternative to current sequential IDs
uuid = { version = "1.0", features = ["v4", "v7"] }

# Validation
validator = { version = "0.16", features = ["derive"] }

[dev-dependencies]
tokio-test = "0.4"
```

### 3.2 Build Configuration

```toml
[profile.release]
codegen-units = 1
lto = true
panic = "abort"
strip = true
```

## 4. Infrastructure as Code (IaC) Setup

### 4.1 Terraform Configuration

#### Directory Structure
```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── modules/
│   ├── lambda/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dynamodb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── global/
    ├── backend.tf
    └── providers.tf
```

#### Main Terraform Configuration (`terraform/modules/dynamodb/main.tf`)
```hcl
resource "aws_dynamodb_table" "urls" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  
  hash_key = "short_code"
  
  attribute {
    name = "short_code"
    type = "S"
  }
  
  attribute {
    name = "original_url"
    type = "S"
  }
  
  global_secondary_index {
    name            = "original_url_index"
    hash_key        = "original_url"
    projection_type = "ALL"
  }
  
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
  }
}
```

#### Lambda Module (`terraform/modules/lambda/main.tf`)
```hcl
resource "aws_lambda_function" "function" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_exec.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"
  
  memory_size = var.memory_size
  timeout     = var.timeout
  
  environment {
    variables = merge({
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      RUST_LOG           = var.rust_log_level
    }, var.additional_env_vars)
  }
  
  tracing_config {
    mode = "Active"
  }
  
  tags = var.tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.function_name}_dynamodb"
  role = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}
```

#### Environment Configuration (`terraform/environments/dev/main.tf`)
```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "squrl-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

module "dynamodb" {
  source = "../../modules/dynamodb"
  
  table_name  = "squrl-urls-${var.environment}"
  environment = var.environment
}

module "create_url_lambda" {
  source = "../../modules/lambda"
  
  function_name       = "squrl-create-url-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/create-url/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  memory_size         = 256
  timeout             = 10
  rust_log_level      = "info"
  environment         = var.environment
  
  tags = local.common_tags
}

module "redirect_lambda" {
  source = "../../modules/lambda"
  
  function_name       = "squrl-redirect-${var.environment}"
  lambda_zip_path     = "../../../target/lambda/redirect/bootstrap.zip"
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  memory_size         = 128
  timeout             = 5
  rust_log_level      = "info"
  environment         = var.environment
  
  tags = local.common_tags
}

# Click tracking is now integrated directly into the redirect Lambda function
# No separate analytics Lambda or Kinesis stream needed
# This simplifies the architecture and reduces operational complexity

locals {
  common_tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
    Repository  = "squrl-proto"
  }
}
```

### 4.2 Deployment Scripts

#### Makefile for Build and Deploy
```makefile
.PHONY: build deploy-dev deploy-prod destroy-dev

# Build all Lambda functions
build:
	cargo lambda build --release
	cp target/lambda/create-url/bootstrap target/lambda/create-url/bootstrap.zip
	cp target/lambda/redirect/bootstrap target/lambda/redirect/bootstrap.zip
	cp target/lambda/analytics/bootstrap target/lambda/analytics/bootstrap.zip

# Deploy to dev environment
deploy-dev: build
	cd terraform/environments/dev && \
	terraform init && \
	terraform plan -out=tfplan && \
	terraform apply tfplan

# Deploy to production
deploy-prod: build
	cd terraform/environments/prod && \
	terraform init && \
	terraform plan -out=tfplan && \
	terraform apply tfplan

# Destroy dev environment
destroy-dev:
	cd terraform/environments/dev && \
	terraform destroy -auto-approve

# Local testing with LocalStack
local-infra:
	docker-compose up -d
	awslocal dynamodb create-table \
		--table-name squrl-urls-local \
		--attribute-definitions \
			AttributeName=short_code,AttributeType=S \
			AttributeName=original_url,AttributeType=S \
		--key-schema AttributeName=short_code,KeyType=HASH \
		--global-secondary-indexes \
			IndexName=original_url_index,Keys=[{AttributeName=original_url,KeyType=HASH}],Projection={ProjectionType=ALL} \
		--billing-mode PAY_PER_REQUEST
```

### 4.3 GitHub Actions CI/CD Pipeline
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
        target: x86_64-unknown-linux-musl
    
    - name: Install cargo-lambda
      run: pip install cargo-lambda
    
    - name: Build Lambda Functions
      run: make build
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5.0
    
    - name: Terraform Init
      run: terraform init
      working-directory: ./terraform/environments/${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
    
    - name: Terraform Plan
      run: terraform plan
      working-directory: ./terraform/environments/${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
    
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
      run: terraform apply -auto-approve
      working-directory: ./terraform/environments/${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}
```

## 5. Implementation Tasks

### 5.1 Week 1 Tasks

#### Day 1-2: Infrastructure Setup
- [ ] Install Terraform and AWS CLI
- [ ] Create S3 bucket for Terraform state
- [ ] Initialize Terraform project structure
- [ ] Write DynamoDB table module
- [ ] Write Lambda function module
- [ ] Write IAM roles and policies
- [ ] Test infrastructure deployment to dev environment
- [ ] Set up local development with LocalStack

#### Day 3-4: Core Library Migration
- [ ] Extract base62 encoding logic into shared library
- [ ] Implement KSUID or nanoid for collision-resistant ID generation
- [ ] Create URL validation and sanitization utilities
- [ ] Implement DynamoDB client wrapper with connection pooling
- [ ] Add comprehensive error handling with custom error types

#### Day 5-7: create-url Lambda
- [ ] Implement create-url Lambda function handler
- [ ] Add URL deduplication logic using GSI query
- [ ] Implement custom short code validation
- [ ] Add TTL support for URL expiration
- [ ] Write unit tests for all core functionality

### 4.2 Week 2 Tasks

#### Day 8-10: redirect Lambda
- [ ] Implement redirect Lambda function handler
- [ ] Add DynamoDB item lookup with error handling
- [ ] Implement click count atomic increment
- [ ] Add basic click count increments to DynamoDB
- [ ] Handle edge cases (expired URLs, missing codes)

#### Day 11-12: Click Tracking Integration
- [ ] Implement direct click count updates in redirect function
- [ ] Update DynamoDB click_count field on each redirect
- [ ] Add privacy-compliant click tracking (no PII)
- [ ] Test click count accuracy and performance
- [ ] Add atomic increment operations for consistency

#### Day 13-14: Integration and Testing
- [ ] Deploy all functions to AWS development environment
- [ ] End-to-end integration testing
- [ ] Load testing with realistic traffic patterns
- [ ] Performance optimization and memory tuning
- [ ] Documentation and deployment scripts

## 5. API Contracts

### 5.1 create-url API Contract

**HTTP Method**: POST
**Path**: `/create`
**Content-Type**: `application/json`

**Request Validation**:
```rust
#[derive(Debug, Deserialize, Validate)]
struct CreateUrlRequest {
    #[validate(url)]
    original_url: String,
    
    #[validate(length(min = 3, max = 20), regex = "^[a-zA-Z0-9_-]+$")]
    custom_code: Option<String>,
    
    #[validate(range(min = 1, max = 87600))]  // Max 10 years
    ttl_hours: Option<u32>,
}
```

**Response Schema**:
```rust
#[derive(Debug, Serialize)]
struct CreateUrlResponse {
    short_code: String,
    original_url: String,
    short_url: String,  // Full shortened URL
    created_at: String,
    expires_at: Option<String>,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
    message: String,
    details: Option<serde_json::Value>,
}
```

### 5.2 redirect API Contract

**HTTP Method**: GET
**Path**: `/{short_code}`

**Response Headers**:
```
Location: {original_url}
Cache-Control: public, max-age=3600
X-Short-Code: {short_code}
```

**Status Codes**:
- `301`: Permanent redirect (default)
- `302`: Temporary redirect (if specified)
- `404`: Short code not found
- `410`: URL expired
- `500`: Internal server error

## 6. Error Handling Patterns

### 6.1 Custom Error Types

```rust
#[derive(Debug, thiserror::Error)]
pub enum UrlShortenerError {
    #[error("Invalid URL: {0}")]
    InvalidUrl(String),
    
    #[error("Short code already exists: {0}")]
    ShortCodeExists(String),
    
    #[error("Short code not found: {0}")]
    ShortCodeNotFound(String),
    
    #[error("URL has expired")]
    UrlExpired,
    
    #[error("Database error: {0}")]
    DatabaseError(#[from] aws_sdk_dynamodb::Error),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
    
    #[error("Rate limit exceeded")]
    RateLimitExceeded,
    
    #[error("Internal server error: {0}")]
    InternalError(#[from] anyhow::Error),
}
```

### 6.2 Lambda Error Response Format

```rust
impl From<UrlShortenerError> for lambda_web::Error {
    fn from(err: UrlShortenerError) -> Self {
        let (status_code, error_type) = match &err {
            UrlShortenerError::InvalidUrl(_) => (400, "InvalidUrl"),
            UrlShortenerError::ShortCodeExists(_) => (409, "ConflictError"),
            UrlShortenerError::ShortCodeNotFound(_) => (404, "NotFound"),
            UrlShortenerError::UrlExpired => (410, "Gone"),
            UrlShortenerError::ValidationError(_) => (400, "ValidationError"),
            UrlShortenerError::RateLimitExceeded => (429, "RateLimitExceeded"),
            _ => (500, "InternalServerError"),
        };
        
        let error_response = ErrorResponse {
            error: error_type.to_string(),
            message: err.to_string(),
            details: None,
        };
        
        lambda_web::Error::new(status_code, serde_json::to_string(&error_response).unwrap())
    }
}
```

## 7. Logging and Monitoring Setup

### 7.1 Structured Logging Configuration

```rust
use tracing::{info, warn, error, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

// Initialize logging in main function
fn init_tracing() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into())
        ))
        .with(tracing_subscriber::fmt::layer().json())
        .init();
}

// Example instrumented function
#[instrument(skip(dynamodb_client), fields(short_code = %short_code))]
async fn lookup_url(
    dynamodb_client: &aws_sdk_dynamodb::Client,
    short_code: &str,
) -> Result<Option<String>, UrlShortenerError> {
    info!("Looking up URL for short code");
    // Implementation...
}
```

### 7.2 CloudWatch Metrics

**Custom Metrics to Track**:
- `url_creation_count` - Counter of URLs created
- `url_lookup_count` - Counter of URL lookups
- `url_lookup_miss` - Counter of failed lookups
- `function_duration` - Duration of Lambda functions
- `database_query_duration` - DynamoDB query latency
- `error_count` by error type

```rust
// Example metric emission
use aws_sdk_cloudwatch::Client as CloudWatchClient;

async fn emit_metric(
    cloudwatch: &CloudWatchClient,
    metric_name: &str,
    value: f64,
    unit: aws_sdk_cloudwatch::types::StandardUnit,
) {
    // Implementation for custom metrics
}
```

## 8. Local Development Setup

### 8.1 Development Dependencies

```bash
# Install Rust and cargo-lambda
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
pip3 install cargo-lambda

# Install AWS CLI and CDK
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
npm install -g aws-cdk

# Install LocalStack for local AWS services
pip3 install localstack[full]
```

### 8.2 Local Testing Environment

```yaml
# docker-compose.yml for local development
version: '3.8'
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=dynamodb,cloudwatch
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - "/tmp/localstack:/tmp/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
```

### 8.3 Development Scripts

```bash
#!/bin/bash
# scripts/dev-setup.sh

# Start LocalStack
docker-compose up -d localstack

# Create DynamoDB tables locally
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
  --table-name squrl-urls \
  --attribute-definitions AttributeName=short_code,AttributeType=S \
  --key-schema AttributeName=short_code,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Build and test Lambda functions
cargo lambda build --release
cargo lambda start --port 9001
```

## 9. Testing Requirements

### 9.1 Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tokio_test;

    #[tokio::test]
    async fn test_create_url_success() {
        // Test successful URL creation
    }

    #[tokio::test]
    async fn test_create_url_duplicate() {
        // Test URL deduplication
    }

    #[tokio::test]
    async fn test_invalid_url() {
        // Test invalid URL handling
    }

    #[tokio::test]
    async fn test_custom_short_code() {
        // Test custom short code functionality
    }

    #[tokio::test]
    async fn test_url_expiration() {
        // Test TTL functionality
    }
}
```

### 9.2 Integration Tests

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;

    #[tokio::test]
    async fn test_end_to_end_flow() {
        // 1. Create a short URL
        // 2. Verify it can be retrieved
        // 3. Verify click counts are updated
        // 4. Test expiration
    }

    #[tokio::test]
    async fn test_high_concurrency() {
        // Test concurrent URL creation and retrieval
    }
}
```

### 9.3 Load Testing

```bash
# Install and run load testing tools
npm install -g artillery

# Load test configuration
# artillery-config.yml
config:
  target: 'https://api.squrl.dev'
  phases:
    - duration: 60
      arrivalRate: 10
    - duration: 120
      arrivalRate: 50
  variables:
    test_urls:
      - "https://example.com/test1"
      - "https://example.com/test2"

scenarios:
  - name: "Create and redirect URLs"
    flow:
      - post:
          url: "/create"
          json:
            original_url: "{{ test_urls[0] }}"
      - get:
          url: "/{{ short_code }}"
```

## 10. Acceptance Criteria

### 10.1 Functional Requirements
- [ ] Successfully create shortened URLs with auto-generated codes
- [ ] Support custom short codes with validation
- [ ] URL deduplication returns existing short codes
- [ ] Redirect function returns correct original URLs
- [ ] TTL-based URL expiration works correctly
- [ ] All invalid inputs return appropriate error responses

### 10.2 Performance Requirements
- [ ] create-url function completes in < 100ms (P95)
- [ ] redirect function completes in < 50ms (P95)
- [ ] Support 1000 concurrent requests without errors
- [ ] DynamoDB read/write operations < 10ms (P95)

### 10.3 Reliability Requirements
- [ ] 99.9% success rate under normal load
- [ ] Graceful error handling with meaningful messages
- [ ] No data loss under failure conditions
- [ ] Proper cleanup of expired URLs

### 10.4 Security Requirements
- [ ] Input validation prevents injection attacks
- [ ] URL validation prevents malicious redirects
- [ ] Rate limiting (to be implemented in Phase 2)
- [ ] No sensitive data in logs

## 11. Week-by-Week Breakdown

### Week 1: Foundation and Core Logic

**Days 1-2: Setup and Infrastructure**
- Set up development environment
- Initialize CDK project for AWS resources
- Create DynamoDB table schema
- Configure local testing with LocalStack

**Days 3-4: Core Libraries**
- Extract and enhance base62 encoding logic
- Implement collision-resistant ID generation
- Create shared utilities for URL validation
- Set up error handling and logging framework

**Days 5-7: create-url Lambda**
- Implement Lambda function handler
- Add DynamoDB integration
- Implement URL deduplication
- Write comprehensive unit tests
- Deploy to development environment

### Week 2: Redirect and Click Tracking

**Days 8-10: redirect Lambda**
- Implement redirect Lambda handler
- Add URL lookup and caching logic
- Implement direct click count updates
- Handle edge cases and error conditions
- Performance optimization

**Days 11-12: Click Tracking Integration**
- Implement privacy-compliant click tracking
- Add atomic increment operations for click_count field
- Test click tracking accuracy and performance
- Implement batching for efficiency

**Days 13-14: Integration and Testing**
- End-to-end integration testing
- Load testing and performance tuning
- Security testing and validation
- Deploy to staging environment
- Complete documentation

## 12. Success Metrics

### 12.1 Technical Metrics
- **Function Performance**:
  - create-url: P95 < 100ms, P99 < 200ms
  - redirect: P95 < 50ms, P99 < 100ms
  - click tracking: Minimal latency impact (< 10ms additional)

- **Database Performance**:
  - DynamoDB queries: P95 < 10ms
  - Write operations: P95 < 15ms
  - No throttling under normal load

- **Reliability**:
  - 99.9% success rate for all functions
  - Zero data corruption incidents
  - Recovery time < 5 minutes for failures

### 12.2 Business Metrics
- **Cost Efficiency**:
  - Lambda cost < $0.50 per 1M requests
  - DynamoDB cost < $1.00 per 1M operations
  - Total infrastructure cost < $2 per 1M URLs processed

- **Scalability**:
  - Handle 10,000 URLs created per minute
  - Support 100,000 redirects per minute
  - Linear scaling with no performance degradation

### 12.3 Operational Metrics
- **Monitoring**:
  - 100% of functions have CloudWatch logs
  - All errors are traceable and actionable
  - Performance dashboards available

- **Development**:
  - All code has > 80% test coverage
  - Complete API documentation
  - Deployment automation functional

## 13. Risk Mitigation

### 13.1 Technical Risks
- **DynamoDB Hot Partitions**: Mitigated by using collision-resistant IDs instead of sequential ones
- **Cold Start Latency**: Accept for Phase 1, optimize in Phase 3 with Provisioned Concurrency
- **Cost Overruns**: Monitor spending with CloudWatch alarms and AWS Budgets

### 13.2 Timeline Risks
- **Learning Curve**: Allocated extra time for AWS SDK integration
- **Testing Complexity**: Prioritize core functionality, implement simple click tracking

## 14. Next Steps (Phase 2 Preview)
After Phase 1 completion, Phase 2 will focus on:
- API Gateway integration with proper authentication
- CloudFront distribution for global edge caching
- Enhanced observability with X-Ray tracing
- Production-ready monitoring and alerting

This milestone document provides a comprehensive roadmap for implementing the serverless foundation of the URL shortener, with specific technical details, acceptance criteria, and success metrics to ensure a successful Phase 1 completion.