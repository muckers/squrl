# justfile for squrl-proto - Rust URL shortener
# Replaces the old Makefile with cargo-lambda-based commands

# Build all Lambda functions for deployment
build:
    @echo "Building all Lambda functions with cargo-lambda..."
    cargo lambda build --release --target x86_64-unknown-linux-musl
    @echo "Creating deployment packages..."
    zip -j target/lambda/create-url/bootstrap.zip target/lambda/create-url/bootstrap
    zip -j target/lambda/redirect/bootstrap.zip target/lambda/redirect/bootstrap
    zip -j target/lambda/analytics/bootstrap.zip target/lambda/analytics/bootstrap

# Build a specific Lambda function
build-function FUNCTION:
    @echo "Building {{FUNCTION}} Lambda function..."
    cargo lambda build --release --target x86_64-unknown-linux-musl --bin {{FUNCTION}}
    @echo "Packaging {{FUNCTION}}..."
    zip -j target/lambda/{{FUNCTION}}/bootstrap.zip target/lambda/{{FUNCTION}}/bootstrap

# Test all packages
test:
    @echo "Running tests for all packages..."
    cargo test

# Run clippy for linting
lint:
    @echo "Running clippy linter..."
    cargo clippy --all-targets --all-features

# Format code (requires rustfmt)
fmt:
    @echo "Formatting code..."
    cargo fmt

# Deploy to dev environment
deploy-dev: build
    @echo "Deploying to dev environment..."
    cd terraform/environments/dev && \
    terraform init && \
    terraform plan -out=tfplan && \
    terraform apply tfplan

# Deploy to production environment
deploy-prod: build
    @echo "Deploying to production environment..."
    cd terraform/environments/prod && \
    terraform init && \
    terraform plan -out=tfplan && \
    terraform apply tfplan

# Destroy dev environment
destroy-dev:
    @echo "Destroying dev environment..."
    cd terraform/environments/dev && \
    terraform destroy -auto-approve

# Set up local infrastructure with LocalStack
local-infra:
    @echo "Setting up local infrastructure..."
    docker compose up -d
    @echo "Waiting for LocalStack to start..."
    sleep 5
    @echo "Creating DynamoDB table (if it doesn't exist)..."
    -awslocal dynamodb create-table \
        --table-name squrl-urls-local \
        --attribute-definitions \
            AttributeName=short_code,AttributeType=S \
            AttributeName=original_url,AttributeType=S \
        --key-schema AttributeName=short_code,KeyType=HASH \
        --global-secondary-indexes \
            'IndexName=original_url_index,KeySchema=[{AttributeName=original_url,KeyType=HASH}],Projection={ProjectionType=ALL}' \
        --billing-mode PAY_PER_REQUEST 2>/dev/null || echo "Table already exists or created successfully"
    @echo "Creating Kinesis stream (if it doesn't exist)..."
    -awslocal kinesis create-stream \
        --stream-name squrl-analytics-local \
        --shard-count 1 2>/dev/null || echo "Stream already exists or created successfully"
    @echo "Local infrastructure is ready!"

# Run local Lambda function for testing - create-url
run-local-create-url:
    @echo "Starting create-url Lambda function locally on port 9001..."
    cd lambda/create-url && AWS_ENDPOINT_URL=http://localhost:4566 DYNAMODB_TABLE_NAME=squrl-urls-local RUST_LOG=debug cargo lambda watch -P 9001

# Run local Lambda function for testing - redirect
run-local-redirect:
    @echo "Starting redirect Lambda function locally on port 9002..."
    cd lambda/redirect && AWS_ENDPOINT_URL=http://localhost:4566 DYNAMODB_TABLE_NAME=squrl-urls-local KINESIS_STREAM_NAME=squrl-analytics-local RUST_LOG=debug cargo lambda watch -P 9002

# Run local Lambda function for testing - analytics
run-local-analytics:
    @echo "Starting analytics Lambda function locally on port 9003..."
    cd lambda/analytics && AWS_ENDPOINT_URL=http://localhost:4566 DYNAMODB_TABLE_NAME=squrl-urls-local RUST_LOG=debug cargo lambda watch -P 9003

# Run all local Lambda functions in background (requires tmux or similar)
run-local-all:
    @echo "This would start all functions - use run-local-* commands in separate terminals"
    @echo "create-url: just run-local-create-url"
    @echo "redirect: just run-local-redirect"
    @echo "analytics: just run-local-analytics"

# Test dev environment - create a shortened URL
dev-test-create URL:
    @echo "Creating shortened URL for: {{URL}}"
    @aws lambda invoke \
        --function-name squrl-create-url-dev \
        --region us-east-1 \
        --payload "{\"original_url\": \"{{URL}}\"}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/create-response.json >/dev/null 2>&1
    @echo "Response:"
    @cat /tmp/create-response.json | jq '.'

# Test dev environment - test redirect
dev-test-redirect SHORT_CODE:
    @echo "Testing redirect for short code: {{SHORT_CODE}}"
    @aws lambda invoke \
        --function-name squrl-redirect-dev \
        --region us-east-1 \
        --payload "{\"short_code\": \"{{SHORT_CODE}}\"}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/redirect-response.json >/dev/null 2>&1
    @echo "Response:"
    @cat /tmp/redirect-response.json | jq '.'

# Test dev environment - full flow test
dev-test:
    @echo "🧪 Testing AWS Lambda Deployment"
    @echo "================================="
    @echo ""
    @echo "1. Creating shortened URL..."
    @aws lambda invoke \
        --function-name squrl-create-url-dev \
        --region us-east-1 \
        --payload '{"original_url": "https://www.example.com/test-page"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/test-create.json
    @echo "Created URL response:"
    @cat /tmp/test-create.json | jq '.'
    @echo ""
    @echo "2. Testing redirect..."
    @just _test-redirect-helper
    @echo ""
    @echo "✅ Test complete!"

# Helper for redirect test (internal command)
_test-redirect-helper:
    #!/bin/bash
    SHORT_CODE=$(cat /tmp/test-create.json | jq -r '.short_code // ""')
    if [ -n "$SHORT_CODE" ] && [ "$SHORT_CODE" != "null" ]; then
        echo "Testing redirect for short code: $SHORT_CODE"
        aws lambda invoke \
            --function-name squrl-redirect-dev \
            --region us-east-1 \
            --payload "{\"short_code\": \"$SHORT_CODE\"}" \
            --cli-binary-format raw-in-base64-out \
            /tmp/test-redirect.json
        echo "Redirect response:"
        cat /tmp/test-redirect.json | jq '.'
    else
        echo "❌ No short code found in response"
        exit 1
    fi

# View dev environment DynamoDB table contents
dev-db-scan:
    @echo "Scanning DynamoDB table squrl-urls-dev:"
    @aws dynamodb scan \
        --table-name squrl-urls-dev \
        --region us-east-1 \
        | jq '.Items[] | {short_code: .short_code.S, original_url: .original_url.S, click_count: .click_count.N, created_at: .created_at.S}'

# Get specific item from dev DynamoDB
dev-db-get SHORT_CODE:
    @echo "Getting item with short_code: {{SHORT_CODE}}"
    @aws dynamodb get-item \
        --table-name squrl-urls-dev \
        --key "{\"short_code\": {\"S\": \"{{SHORT_CODE}}\"}}" \
        --region us-east-1 \
        | jq '.Item | {short_code: .short_code.S, original_url: .original_url.S, click_count: .click_count.N, created_at: .created_at.S}'

# View dev environment CloudWatch logs
dev-logs-create-url:
    @echo "Recent logs for create-url Lambda:"
    @aws logs tail /aws/lambda/squrl-create-url-dev --since 10m --region us-east-1

dev-logs-redirect:
    @echo "Recent logs for redirect Lambda:"
    @aws logs tail /aws/lambda/squrl-redirect-dev --since 10m --region us-east-1

dev-logs-analytics:
    @echo "Recent logs for analytics Lambda:"
    @aws logs tail /aws/lambda/squrl-analytics-dev --since 10m --region us-east-1

# View all dev logs
dev-logs:
    @echo "=== Create URL Lambda Logs ==="
    @aws logs tail /aws/lambda/squrl-create-url-dev --since 5m --region us-east-1 | head -5
    @echo ""
    @echo "=== Redirect Lambda Logs ==="
    @aws logs tail /aws/lambda/squrl-redirect-dev --since 5m --region us-east-1 | head -5
    @echo ""
    @echo "=== Analytics Lambda Logs ==="
    @aws logs tail /aws/lambda/squrl-analytics-dev --since 5m --region us-east-1 | head -5

# List all dev environment resources
dev-status:
    @echo "📊 Dev Environment Status"
    @echo "========================"
    @echo ""
    @echo "Lambda Functions:"
    @aws lambda list-functions --region us-east-1 | jq -r '.Functions[] | select(.FunctionName | contains("squrl")) | select(.FunctionName | contains("dev")) | "  - \(.FunctionName) (\(.Runtime), \(.MemorySize)MB, \(.Timeout)s)"'
    @echo ""
    @echo "DynamoDB Tables:"
    @aws dynamodb list-tables --region us-east-1 | jq -r '.TableNames[] | select(. | contains("squrl")) | select(. | contains("dev")) | "  - \(.)"'
    @echo ""
    @echo "Kinesis Streams:"
    @aws kinesis list-streams --region us-east-1 | jq -r '.StreamNames[] | select(. | contains("squrl")) | select(. | contains("dev")) | "  - \(.)"'

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    cargo clean
    @echo "Removing Lambda deployment packages..."
    @find target/lambda -name "bootstrap.zip" -delete 2>/dev/null || true
    @rm -rf target/lambda-packages 2>/dev/null || true

# Install development dependencies
install-deps:
    @echo "Installing development dependencies..."
    @echo "cargo-lambda should be installed via: pip install cargo-lambda"
    @echo "awslocal should be installed via: pip install awscli-local[ver1]"
    @echo "Note: cargo-lambda is already installed"

# Package Lambda functions (create zip files for manual deployment)
package:
    @echo "Packaging Lambda functions..."
    cargo lambda build --release --target x86_64-unknown-linux-musl
    @mkdir -p target/lambda-packages
    @echo "Packaging create-url..."
    @zip -j target/lambda-packages/create-url.zip target/lambda/create-url/bootstrap
    @echo "Packaging redirect..."
    @zip -j target/lambda-packages/redirect.zip target/lambda/redirect/bootstrap
    @echo "Packaging analytics..."
    @zip -j target/lambda-packages/analytics.zip target/lambda/analytics/bootstrap
    @echo "Lambda packages created in target/lambda-packages/"

# Watch and rebuild on changes (requires cargo-watch)
watch:
    @echo "Watching for changes and rebuilding..."
    cargo watch -x "lambda build --release --target x86_64-unknown-linux-musl"

# Show build status and artifact information
status:
    @echo "Build Status and Artifacts:"
    @echo "=========================="
    @if [ -d "target/lambda" ]; then \
        echo "Lambda artifacts found:"; \
        ls -la target/lambda/*/bootstrap 2>/dev/null || echo "No bootstrap files found"; \
    else \
        echo "No Lambda artifacts found. Run 'just build' first."; \
    fi
    @echo ""
    @echo "Cargo workspace members:"
    @cargo metadata --format-version 1 | jq -r '.workspace_members[]' | sed 's/.*#//' | sed 's/@.*//'

# Help - show available commands
help:
    @echo "Available commands:"
    @echo "=================="
    @just --list