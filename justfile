# justfile for squrl - Rust URL shortener
# Simplified with essential commands only

# =============================================================================
# Build Commands
# =============================================================================

# Build all Lambda functions for deployment
build:
    @echo "Building all Lambda functions with cargo-lambda..."
    cargo lambda build --release --target x86_64-unknown-linux-musl
    @echo "Creating deployment packages..."
    zip -j target/lambda/create-url/bootstrap.zip target/lambda/create-url/bootstrap
    zip -j target/lambda/redirect/bootstrap.zip target/lambda/redirect/bootstrap
    zip -j target/lambda/analytics/bootstrap.zip target/lambda/analytics/bootstrap
    zip -j target/lambda/get-stats/bootstrap.zip target/lambda/get-stats/bootstrap

# Build a specific Lambda function
build-function FUNCTION:
    @echo "Building {{FUNCTION}} Lambda function..."
    cargo lambda build --release --target x86_64-unknown-linux-musl --bin {{FUNCTION}}
    @echo "Packaging {{FUNCTION}}..."
    zip -j target/lambda/{{FUNCTION}}/bootstrap.zip target/lambda/{{FUNCTION}}/bootstrap

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    cargo clean
    @echo "Removing Lambda deployment packages..."
    @find target/lambda -name "bootstrap.zip" -delete 2>/dev/null || true
    @rm -rf target/lambda-packages 2>/dev/null || true

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

# =============================================================================
# Development Commands
# =============================================================================

# Test all packages
test:
    @echo "Running tests for all packages..."
    cargo test

# Run clippy for linting
lint:
    @echo "Running clippy linter..."
    cargo clippy --all-targets --all-features

# Format code
fmt:
    @echo "Formatting code..."
    cargo fmt

# =============================================================================
# Deployment Commands
# =============================================================================

# Deploy to dev environment
deploy-dev: build
    #!/bin/bash
    set -euo pipefail
    echo "Deploying to dev environment..."
    cd terraform/environments/dev
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

# Deploy web UI to production
deploy-web-ui-prod:
    #!/bin/bash
    set -euo pipefail
    echo "📤 Deploying web UI to production..."
    
    # Get S3 bucket name from Terraform outputs
    cd terraform/environments/prod
    
    # Initialize terraform to pull state from S3
    terraform init -input=false > /dev/null 2>&1 || true
    
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    
    if [ -z "$S3_BUCKET" ]; then
        echo "❌ Could not get S3 bucket name from Terraform outputs"
        exit 1
    fi
    
    if [ -z "$CLOUDFRONT_ID" ]; then
        echo "⚠️  Warning: Could not get CloudFront distribution ID"
    fi
    
    echo "  S3 Bucket: $S3_BUCKET"
    echo "  CloudFront ID: $CLOUDFRONT_ID"
    
    # Change to project root
    cd ../../..
    
    # Check if web-ui directory exists
    if [ ! -d "web-ui" ]; then
        echo "❌ Web UI directory not found"
        exit 1
    fi
    
    # Upload files to S3
    echo "Uploading files to S3..."
    
    # Upload HTML files
    for file in web-ui/*.html; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  Uploading $filename..."
            aws s3 cp "$file" "s3://$S3_BUCKET/$filename" \
                --content-type "text/html" \
                --cache-control "public, max-age=3600"
        fi
    done
    
    # Upload robots.txt
    if [ -f "web-ui/robots.txt" ]; then
        echo "  Uploading robots.txt..."
        aws s3 cp "web-ui/robots.txt" "s3://$S3_BUCKET/robots.txt" \
            --content-type "text/plain" \
            --cache-control "public, max-age=86400"
    fi
    
    # Upload images
    for ext in jpg jpeg png gif svg; do
        for file in web-ui/*.$ext; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                echo "  Uploading $filename..."
                case "$ext" in
                    jpg|jpeg) content_type="image/jpeg" ;;
                    png) content_type="image/png" ;;
                    gif) content_type="image/gif" ;;
                    svg) content_type="image/svg+xml" ;;
                esac
                aws s3 cp "$file" "s3://$S3_BUCKET/$filename" \
                    --content-type "$content_type" \
                    --cache-control "public, max-age=604800"
            fi
        done
    done
    
    # Upload CSS files
    for file in web-ui/*.css; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  Uploading $filename..."
            aws s3 cp "$file" "s3://$S3_BUCKET/$filename" \
                --content-type "text/css" \
                --cache-control "public, max-age=86400"
        fi
    done
    
    # Upload JS files
    for file in web-ui/*.js; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  Uploading $filename..."
            aws s3 cp "$file" "s3://$S3_BUCKET/$filename" \
                --content-type "application/javascript" \
                --cache-control "public, max-age=86400"
        fi
    done
    
    echo "✅ Files uploaded successfully"
    
    # Invalidate CloudFront cache
    if [ -n "$CLOUDFRONT_ID" ]; then
        echo "🔄 Invalidating CloudFront cache..."
        INVALIDATION_ID=$(aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_ID" \
            --paths "/*" \
            --query 'Invalidation.Id' \
            --output text)
        
        if [ -n "$INVALIDATION_ID" ]; then
            echo "✅ CloudFront invalidation created: $INVALIDATION_ID"
        else
            echo "⚠️  Failed to create CloudFront invalidation"
        fi
    fi
    
    echo "🎉 Web UI deployment completed!"
    echo "   Production URL: https://squrl.pub"

# Deploy to production environment
deploy-prod: build
    #!/bin/bash
    set -euo pipefail
    echo "Deploying to production environment..."
    cd terraform/environments/prod
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    
    # Deploy web UI after Terraform completes
    cd ../../..
    echo ""
    echo "Now deploying web UI..."
    just deploy-web-ui-prod

# Destroy dev environment
destroy-dev:
    #!/bin/bash
    set -euo pipefail
    echo "Destroying dev environment..."
    cd terraform/environments/dev
    terraform destroy -auto-approve

# =============================================================================
# Testing Commands  
# =============================================================================

# WAF rate limiting test with oha (high-performance load testing)
test-waf-oha ENV="staging":
    #!/bin/bash
    set -euo pipefail
    echo "🛡️  Testing WAF rate limiting with oha (Rust load testing tool)"
    echo "WARNING: This test will trigger WAF rate limiting and may temporarily block your IP"
    echo ""
    
    # Set endpoint URLs based on environment
    case "{{ENV}}" in
        "dev"|"staging")
            API_BASE_URL="https://staging.squrl.pub"
            ;;
        "prod"|"production")
            echo "⚠️  WAF testing against PRODUCTION will test actual rate limits"
            echo "   This will hit the live squrl.pub service and may trigger blocking"
            read -p "Are you sure you want to test WAF against PRODUCTION squrl.pub? (type 'YES'): " -r
            if [[ $REPLY != "YES" ]]; then
                echo "WAF test cancelled"
                exit 0
            fi
            API_BASE_URL="https://squrl.pub"
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            echo "Available environments: dev, staging, prod"
            exit 1
            ;;
    esac
    
    echo "Testing environment: {{ENV}}"
    echo "API Base URL: $API_BASE_URL"
    echo ""
    
    # Test connectivity first
    echo "🔍 Testing connectivity..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "✅ API endpoint is accessible (HTTP $HTTP_CODE)"
    else
        echo "❌ Cannot connect to $API_BASE_URL (HTTP $HTTP_CODE)"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo ""
    echo "🚀 Starting WAF rate limiting tests..."
    
    # Test 1: Global WAF limit (1000 req/5min)
    echo "1. Testing WAF global rate limit..."
    oha -z 300s -c 5 -q 4 --latency-correction \
        -H "Content-Type: application/json" \
        -H "User-Agent: WAF-Test-oha/1.0" \
        -m POST \
        -d '{"original_url":"https://example.com/waf-test-global"}' \
        "$API_BASE_URL/create" || true
    
    echo ""
    echo "2. Testing WAF burst protection..."
    oha -n 1200 --burst-delay 1s --burst-rate 25 \
        -H "Content-Type: application/json" \
        -H "User-Agent: WAF-Test-oha/1.0" \
        -m POST \
        -d '{"original_url":"https://example.com/waf-test-burst"}' \
        "$API_BASE_URL/create" || true
    
    echo ""
    echo "✅ WAF rate limiting tests completed"
    echo "💡 Monitor CloudWatch WAF metrics and wait 5+ minutes for rate limit reset"

# =============================================================================
# Utility Commands
# =============================================================================

# Show dev environment status and deployed resources
dev-status:
    #!/bin/bash
    echo "📊 Dev Environment Status"
    echo "========================"
    echo ""
    
    # Check terraform state
    pushd terraform/environments/dev > /dev/null 2>&1
    if [ -d ".terraform" ]; then
        echo "📋 Terraform Resources:"
        terraform state list 2>/dev/null | head -10 | sed 's/^/  - /' || echo "  ⚠️  No terraform state found"
        echo ""
        echo "Endpoint URLs:"
        API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "Not deployed")
        CF_URL=$(terraform output -raw cloudfront_url 2>/dev/null || echo "Not deployed")
        echo "  - API Gateway: $API_URL"
        echo "  - CloudFront: $CF_URL"
    else
        echo "⚠️  Terraform not initialized. Run 'just deploy-dev' first."
    fi
    popd > /dev/null 2>&1

# Show available commands
help:
    @echo "Available commands:"
    @echo "=================="
    @just --list