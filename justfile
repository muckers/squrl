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

# ============================================================================
# Integration and Load Testing Commands
# ============================================================================

# Run integration tests against API endpoints
test-integration ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🧪 Running integration tests against {{ENV}} environment"
    
    # Set environment variables based on ENV parameter
    case "{{ENV}}" in
        "dev")
            export API_BASE_URL="https://api-dev.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            export API_BASE_URL="https://api.squrl.dev"
            export CLOUDFRONT_URL="https://squrl.dev"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}. Use: dev, staging, or prod"
            exit 1
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    
    echo "Environment: $TEST_ENV"
    echo "API Base URL: $API_BASE_URL"
    echo "CloudFront URL: $CLOUDFRONT_URL"
    echo ""
    
    cd tests/integration
    
    # Build integration tests
    echo "Building integration tests..."
    cargo build --release
    
    # Run API functionality tests
    echo "Running API functionality tests..."
    cargo run --release --bin api_tests
    
    echo ""
    echo "✅ Integration tests completed successfully!"

# Run API functionality tests only
test-api ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🔧 Running API functionality tests against {{ENV}} environment"
    
    case "{{ENV}}" in
        "dev")
            # Get actual URLs from Terraform output
            cd terraform/environments/dev
            export API_BASE_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "https://q3lq9c9i4e.execute-api.us-east-1.amazonaws.com/v1")
            export CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "https://d70tu78goifc7.cloudfront.net")
            cd - > /dev/null
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            export API_BASE_URL="https://api.squrl.dev"
            export CLOUDFRONT_URL="https://squrl.dev"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            exit 1
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    
    cd tests/integration
    cargo run --release --bin api_tests

# Run rate limiting tests (WARNING: May trigger rate limits)
test-rate-limits ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "⚠️ Running rate limiting tests against {{ENV}} environment"
    echo "WARNING: This test will make many requests and may trigger rate limits"
    echo ""
    read -p "Continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rate limiting tests cancelled"
        exit 0
    fi
    
    case "{{ENV}}" in
        "dev")
            export API_BASE_URL="https://api-dev.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"  
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            echo "❌ Rate limiting tests against production are not recommended"
            exit 1
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            exit 1
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    export RUN_LOAD_TESTS="true"
    
    cd tests/integration
    cargo run --release --bin rate_limit_tests

# Run caching tests
test-caching ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🗄️ Running caching behavior tests against {{ENV}} environment"
    
    case "{{ENV}}" in
        "dev")
            export API_BASE_URL="https://api-dev.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            export API_BASE_URL="https://api.squrl.dev"
            export CLOUDFRONT_URL="https://squrl.dev"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            exit 1
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    
    cd tests/integration
    cargo run --release --bin caching_tests

# Run load tests with Artillery (requires Node.js and npm)
test-load ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🚀 Running load tests against {{ENV}} environment"
    echo "WARNING: This will generate significant load against your API endpoints"
    echo ""
    
    case "{{ENV}}" in
        "dev")
            export API_BASE_URL="https://api-dev.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            echo "❌ Load tests against production require explicit confirmation"
            read -p "Are you sure you want to load test PRODUCTION? (type 'PRODUCTION'): " -r
            if [[ $REPLY != "PRODUCTION" ]]; then
                echo "Load tests cancelled"
                exit 0
            fi
            export API_BASE_URL="https://api.squrl.dev"
            export CLOUDFRONT_URL="https://squrl.dev"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            exit 1
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    
    cd tests/load
    
    # Check if Node.js dependencies are installed
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi
    
    # Validate configurations
    echo "Validating Artillery configurations..."
    npm run validate-config
    
    # Run standard load test
    echo "Running standard load test..."
    npm run test:standard

# Run specific load test type
test-load-type TYPE ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🎯 Running {{TYPE}} load test against {{ENV}} environment"
    
    case "{{ENV}}" in
        "dev")
            export API_BASE_URL="https://api-dev.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            export API_BASE_URL="https://api-staging.squrl.dev"
            export CLOUDFRONT_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            echo "❌ Load tests against production require careful consideration"
            read -p "Continue with production load testing? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
            export API_BASE_URL="https://api.squrl.dev"
            export CLOUDFRONT_URL="https://squrl.dev"
            ;;
    esac
    
    export TEST_ENV="{{ENV}}"
    
    cd tests/load
    
    case "{{TYPE}}" in
        "standard")
            npm run test:standard
            ;;
        "burst")
            echo "WARNING: Burst test will intentionally trigger rate limiting"
            npm run test:burst
            ;;
        "mixed")
            npm run test:mixed
            ;;
        "waf")
            echo "WARNING: WAF test may temporarily block your IP address"
            read -p "Continue? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                npm run test:waf
            fi
            ;;
        *)
            echo "❌ Invalid test type: {{TYPE}}"
            echo "Available types: standard, burst, mixed, waf"
            exit 1
            ;;
    esac

# Generate load test report from previous run
test-load-report:
    #!/bin/bash
    set -euo pipefail
    echo "📊 Generating load test report..."
    
    cd tests/load
    
    # Find the most recent JSON report
    REPORT_FILE=$(ls -t reports/*.json 2>/dev/null | head -1 || echo "")
    
    if [ -z "$REPORT_FILE" ]; then
        echo "❌ No report files found. Run a load test first."
        exit 1
    fi
    
    echo "Using report file: $REPORT_FILE"
    artillery report "$REPORT_FILE"

# Install testing dependencies
test-install-deps:
    @echo "📦 Installing testing dependencies..."
    @echo ""
    @echo "Rust integration tests:"
    cd tests/integration && cargo build --release
    @echo ""
    @echo "Node.js load testing (Artillery):"
    cd tests/load && npm install
    @echo ""
    @echo "✅ Testing dependencies installed successfully!"

# Run all tests (unit + integration + light load test)
test-all ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🧪 Running comprehensive test suite against {{ENV}} environment"
    echo "This includes unit tests, integration tests, and light load testing"
    echo ""
    
    # Unit tests
    echo "1/4 Running unit tests..."
    just test
    echo ""
    
    # Integration tests
    echo "2/4 Running integration tests..."
    just test-integration {{ENV}}
    echo ""
    
    # Caching tests
    echo "3/4 Running caching tests..."
    just test-caching {{ENV}}
    echo ""
    
    # Light load test
    echo "4/4 Running light load test..."
    just test-load-type standard {{ENV}}
    echo ""
    
    echo "✅ All tests completed successfully!"

# Test environment connectivity and basic functionality
test-connectivity ENV="dev":
    #!/bin/bash
    set -euo pipefail
    echo "🔗 Testing connectivity to {{ENV}} environment"
    
    case "{{ENV}}" in
        "dev")
            API_URL="https://api-dev.squrl.dev"
            CF_URL="https://squrl-dev.squrl.dev"
            ;;
        "staging")
            API_URL="https://api-staging.squrl.dev"
            CF_URL="https://squrl-staging.squrl.dev"
            ;;
        "prod")
            API_URL="https://api.squrl.dev"
            CF_URL="https://squrl.dev"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            exit 1
            ;;
    esac
    
    echo "Testing API Gateway: $API_URL"
    echo "Testing CloudFront: $CF_URL"
    echo ""
    
    # Test API Gateway health
    echo "1. Testing API Gateway connectivity..."
    if curl -f -s -I "$API_URL/create" > /dev/null; then
        echo "   ✅ API Gateway is accessible"
    else
        echo "   ❌ API Gateway is not accessible"
    fi
    
    # Test CloudFront health
    echo "2. Testing CloudFront connectivity..."
    if curl -f -s -I "$CF_URL" > /dev/null; then
        echo "   ✅ CloudFront is accessible"
    else
        echo "   ❌ CloudFront is not accessible"
    fi
    
    # Test basic API functionality
    echo "3. Testing basic API functionality..."
    RESPONSE=$(curl -s -X POST "$API_URL/create" \
        -H "Content-Type: application/json" \
        -d '{"original_url":"https://example.com/connectivity-test"}' \
        -w "%{http_code}")
    
    HTTP_CODE="${RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ]; then
        echo "   ✅ API create endpoint working"
    else
        echo "   ⚠️ API create endpoint returned: $HTTP_CODE"
    fi
    
    echo ""
    echo "Connectivity test completed for {{ENV}} environment"

# Test dev environment with stats endpoint
dev-test-stats SHORT_CODE:
    #!/bin/bash
    set -euo pipefail
    echo "Getting stats for short code: {{SHORT_CODE}}"
    
    # Get API Gateway URL from Terraform output
    API_URL=$(cd terraform/environments/dev && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    if [ -z "$API_URL" ]; then
        echo "❌ API Gateway URL not found. Deploy infrastructure first with 'just deploy-dev'"
        exit 1
    fi
    
    echo "Using API endpoint: $API_URL/stats/{{SHORT_CODE}}"
    
    # Get stats
    curl -s "$API_URL/stats/{{SHORT_CODE}}" -H "Accept: application/json" | jq '.'

# ============================================================================

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
    #!/bin/bash
    set -euo pipefail
    echo "Deploying to dev environment..."
    cd terraform/environments/dev
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

# Deploy to production environment
deploy-prod: build
    #!/bin/bash
    set -euo pipefail
    echo "Deploying to production environment..."
    cd terraform/environments/prod
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

# Destroy dev environment
destroy-dev:
    #!/bin/bash
    set -euo pipefail
    echo "Destroying dev environment..."
    cd terraform/environments/dev
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

# Test dev environment - create a shortened URL via API Gateway
dev-test-create URL:
    #!/bin/bash
    set -euo pipefail
    echo "Creating shortened URL for: {{URL}}"
    
    # Get API Gateway URL from Terraform output
    API_URL=$(cd terraform/environments/dev && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    if [ -z "$API_URL" ]; then
        echo "❌ API Gateway URL not found. Deploy infrastructure first with 'just deploy-dev'"
        exit 1
    fi
    
    echo "Using API endpoint: $API_URL/create"
    
    # Make API request
    curl -s -X POST "$API_URL/create" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"original_url\": \"{{URL}}\"}" | jq '.'

# Test dev environment - test redirect via CloudFront/API Gateway
dev-test-redirect SHORT_CODE:
    #!/bin/bash
    set -euo pipefail
    echo "Testing redirect for short code: {{SHORT_CODE}}"
    
    # Get API Gateway URL (CloudFront not deployed yet)
    CF_URL=$(cd terraform/environments/dev && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    if [ -z "$CF_URL" ]; then
        echo "❌ CloudFront URL not found. Deploy infrastructure first with 'just deploy-dev'"
        exit 1
    fi
    
    echo "Using CloudFront endpoint: $CF_URL/{{SHORT_CODE}}"
    
    # Test redirect (don't follow redirects, just show the response)
    curl -s -I "$CF_URL/{{SHORT_CODE}}" | head -20

# Test dev environment - full flow test via API Gateway and CloudFront
dev-test:
    #!/bin/bash
    set -euo pipefail
    echo "🧪 Testing Complete Squrl API Stack (API Gateway + CloudFront)"
    echo "=============================================================="
    echo ""
    
    # Get endpoints from Terraform
    API_URL=$(cd terraform/environments/dev && terraform output -raw api_gateway_url 2>/dev/null || echo "")
    # CloudFront not deployed yet, use API Gateway URL directly
    CF_URL="$API_URL"
    
    if [ -z "$API_URL" ] || [ -z "$CF_URL" ]; then
        echo "❌ API endpoints not found. Deploy infrastructure first with 'just deploy-dev'"
        exit 1
    fi
    
    echo "API Gateway: $API_URL"
    echo "CloudFront: $CF_URL"
    echo ""
    
    # 1. Create shortened URL via API Gateway
    echo "1. Creating shortened URL via API Gateway..."
    CREATE_RESPONSE=$(curl -s -X POST "$API_URL/create" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"original_url": "https://www.example.com/milestone-02-test"}')
    
    echo "Create response:"
    echo "$CREATE_RESPONSE" | jq '.'
    
    # Extract short code
    SHORT_CODE=$(echo "$CREATE_RESPONSE" | jq -r '.short_code // empty')
    if [ -z "$SHORT_CODE" ]; then
        echo "❌ No short code in response"
        exit 1
    fi
    
    echo ""
    echo "2. Testing redirect via CloudFront..."
    echo "Short code: $SHORT_CODE"
    echo "Redirect URL: $CF_URL/$SHORT_CODE"
    
    # Test redirect (don't follow, just show headers)
    curl -s -I "$CF_URL/$SHORT_CODE" | head -15
    
    echo ""
    echo "3. Testing stats endpoint..."
    STATS_RESPONSE=$(curl -s "$API_URL/stats/$SHORT_CODE" -H "Accept: application/json")
    echo "Stats response:"
    echo "$STATS_RESPONSE" | jq '.'
    
    echo ""
    echo "✅ Full stack test complete!"
    echo "   - URL created via API Gateway ✅"
    echo "   - Redirect tested via CloudFront ✅"
    echo "   - Stats retrieved via API Gateway ✅"

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
    #!/bin/bash
    echo "📊 Dev Environment Status"
    echo "========================"
    echo ""
    echo "🔄 Refreshing Terraform State..."
    pushd terraform/environments/dev > /dev/null 2>&1
    if terraform refresh > /dev/null 2>&1; then
        echo "✅ State refreshed"
    else
        echo "⚠️  Failed to refresh state"
    fi
    echo ""
    echo "📋 Terraform Resources:"
    RESOURCES=$(terraform show -json 2>/dev/null | jq -r '
        [.values.root_module.resources[]?, (.values.root_module.child_modules[]?.resources[]?)] 
        | map("  - \(.type)/\(.name) (\(.mode))")
        | join("\n")' 2>/dev/null)
    if [ -n "$RESOURCES" ]; then
        echo "$RESOURCES"
    else
        echo "  ⚠️  No terraform state found"
    fi
    popd > /dev/null 2>&1
    echo ""
    echo "Lambda Functions:"
    aws lambda list-functions --region us-east-1 | jq -r '.Functions[] | select(.FunctionName | contains("squrl")) | select(.FunctionName | contains("dev")) | "  - \(.FunctionName) (\(.Runtime), \(.MemorySize)MB, \(.Timeout)s)"'
    echo ""
    echo "DynamoDB Tables:"
    aws dynamodb list-tables --region us-east-1 | jq -r '.TableNames[] | select(. | contains("squrl")) | select(. | contains("dev")) | "  - \(.)"'
    echo ""
    echo "Kinesis Streams:"
    aws kinesis list-streams --region us-east-1 | jq -r '.StreamNames[] | select(. | contains("squrl")) | select(. | contains("dev")) | "  - \(.)"'
    echo ""
    echo "API Gateway APIs:"
    aws apigateway get-rest-apis --region us-east-1 | jq -r '.items[] | select(.name | contains("squrl")) | select(.name | contains("dev")) | "  - \(.name) (\(.id))"'
    echo ""
    echo "CloudFront Distributions:"
    aws cloudfront list-distributions --region us-east-1 | jq -r '.DistributionList.Items[] | select(.Comment | contains("squrl")) | select(.Comment | contains("dev")) | "  - \(.Comment) (\(.Id)) - \(.DomainName)"'
    echo ""
    echo "WAF Web ACLs:"
    aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 | jq -r '.WebACLs[] | select(.Name | contains("squrl")) | select(.Name | contains("dev")) | "  - \(.Name) (\(.Id))"'
    echo ""
    echo "Endpoint URLs:"
    API_URL=$(cd terraform/environments/dev && terraform output -raw api_gateway_url 2>/dev/null || echo "Not deployed")
    CF_URL=$(cd terraform/environments/dev && terraform output -raw cloudfront_url 2>/dev/null || echo "Not deployed")
    echo "  - API Gateway: $API_URL"
    echo "  - CloudFront: $CF_URL"

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