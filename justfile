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
# Validation Commands
# =============================================================================

# Validate production infrastructure deployment and health
validate-prod:
    #!/bin/bash
    set -euo pipefail
    
    echo "🔍 Validating Production Infrastructure & Deployment"
    echo "=================================================="
    echo ""
    
    VALIDATION_FAILED=false
    
    # Change to prod terraform directory
    cd terraform/environments/prod
    
    # Get AWS region from Terraform config
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || grep 'aws_region' terraform.tfvars | cut -d'"' -f2 || echo "us-east-1")
    export AWS_DEFAULT_REGION="$AWS_REGION"
    echo "🌐 Using AWS region: $AWS_REGION"
    echo ""
    
    echo "1. 📋 Terraform State Validation"
    echo "--------------------------------"
    
    # Check terraform initialization
    if [ ! -d ".terraform" ]; then
        echo "❌ Terraform not initialized"
        VALIDATION_FAILED=true
    else
        echo "✅ Terraform initialized"
        
        # Initialize to ensure latest state
        terraform init -input=false > /dev/null 2>&1
        
        # Check if terraform plan shows no changes
        echo "   Checking if infrastructure matches Terraform config..."
        PLAN_EXIT_CODE=0
        terraform plan -detailed-exitcode > /dev/null 2>&1 || PLAN_EXIT_CODE=$?
        
        if [ $PLAN_EXIT_CODE -eq 0 ]; then
            echo "✅ Infrastructure matches Terraform configuration (no changes)"
        elif [ $PLAN_EXIT_CODE -eq 2 ]; then
            echo "⚠️  Infrastructure changes detected - run 'terraform plan' for details"
            # Don't fail validation for planned changes, only for errors
        else
            echo "❌ Terraform plan failed (exit code: $PLAN_EXIT_CODE)"
            VALIDATION_FAILED=true
        fi
    fi
    
    echo ""
    echo "2. 🏗️  AWS Infrastructure Validation"
    echo "-----------------------------------"
    
    # Get outputs from Terraform
    API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    API_GATEWAY_ID=$(terraform output -raw api_gateway_id 2>/dev/null || echo "")
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    # Check API Gateway
    if [ -n "$API_GATEWAY_ID" ]; then
        if aws apigateway get-rest-api --rest-api-id "$API_GATEWAY_ID" --region "$AWS_REGION" > /dev/null 2>&1; then
            echo "✅ API Gateway exists: $API_GATEWAY_ID"
            
            # Check deployment stage (assuming v1 based on common pattern)
            STAGE_NAME="v1"
            if aws apigateway get-stage --rest-api-id "$API_GATEWAY_ID" --stage-name "$STAGE_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
                echo "✅ API Gateway $STAGE_NAME stage deployed"
            else
                echo "❌ API Gateway $STAGE_NAME stage not found"
                VALIDATION_FAILED=true
            fi
        else
            echo "❌ API Gateway not found: $API_GATEWAY_ID"
            VALIDATION_FAILED=true
        fi
    else
        echo "❌ API Gateway ID not available from Terraform"
        VALIDATION_FAILED=true
    fi
    
    # Check DynamoDB table
    if [ -n "$DYNAMODB_TABLE" ]; then
        if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" > /dev/null 2>&1; then
            TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" --query 'Table.TableStatus' --output text)
            if [ "$TABLE_STATUS" = "ACTIVE" ]; then
                # Get item count
                ITEM_COUNT=$(aws dynamodb scan --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" --select COUNT --query 'Count' --output text 2>/dev/null || echo "unknown")
                echo "✅ DynamoDB table active: $DYNAMODB_TABLE (count: $ITEM_COUNT)"
            else
                echo "❌ DynamoDB table not active: $DYNAMODB_TABLE (Status: $TABLE_STATUS)"
                VALIDATION_FAILED=true
            fi
        else
            echo "❌ DynamoDB table not found: $DYNAMODB_TABLE"
            VALIDATION_FAILED=true
        fi
    else
        echo "❌ DynamoDB table name not available from Terraform"
        VALIDATION_FAILED=true
    fi
    
    # Check CloudFront distribution
    if [ -n "$CLOUDFRONT_ID" ]; then
        if aws cloudfront get-distribution --id "$CLOUDFRONT_ID" > /dev/null 2>&1; then
            CF_STATUS=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.Status' --output text)
            if [ "$CF_STATUS" = "Deployed" ]; then
                echo "✅ CloudFront distribution deployed: $CLOUDFRONT_ID"
            else
                echo "❌ CloudFront distribution not deployed: $CLOUDFRONT_ID (Status: $CF_STATUS)"
                VALIDATION_FAILED=true
            fi
        else
            echo "❌ CloudFront distribution not found: $CLOUDFRONT_ID"
            VALIDATION_FAILED=true
        fi
    else
        echo "❌ CloudFront distribution ID not available from Terraform"
        VALIDATION_FAILED=true
    fi
    
    # Check S3 bucket
    if [ -n "$S3_BUCKET" ]; then
        if aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" > /dev/null 2>&1; then
            echo "✅ S3 bucket exists: $S3_BUCKET"
        else
            echo "❌ S3 bucket not accessible: $S3_BUCKET"
            VALIDATION_FAILED=true
        fi
    else
        echo "❌ S3 bucket name not available from Terraform"
        VALIDATION_FAILED=true
    fi
    
    echo ""
    echo "3. 🚀 Lambda Function Validation"
    echo "-------------------------------"
    
    # Get Lambda function names
    CREATE_URL_FUNCTION=$(terraform output -json lambda_function_names 2>/dev/null | jq -r '.create_url // empty' || echo "")
    REDIRECT_FUNCTION=$(terraform output -json lambda_function_names 2>/dev/null | jq -r '.redirect // empty' || echo "")
    GET_STATS_FUNCTION=$(terraform output -json lambda_function_names 2>/dev/null | jq -r '.get_stats // empty' || echo "")
    
    # Validate each Lambda function
    for FUNC_NAME in "$CREATE_URL_FUNCTION" "$REDIRECT_FUNCTION" "$GET_STATS_FUNCTION"; do
        if [ -n "$FUNC_NAME" ] && [ "$FUNC_NAME" != "null" ]; then
            if aws lambda get-function --function-name "$FUNC_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
                FUNC_STATE=$(aws lambda get-function --function-name "$FUNC_NAME" --region "$AWS_REGION" --query 'Configuration.State' --output text)
                LAST_UPDATE=$(aws lambda get-function --function-name "$FUNC_NAME" --region "$AWS_REGION" --query 'Configuration.LastUpdateStatus' --output text)
                
                if [ "$FUNC_STATE" = "Active" ] && [ "$LAST_UPDATE" = "Successful" ]; then
                    echo "✅ Lambda function active: $FUNC_NAME"
                else
                    echo "❌ Lambda function issues: $FUNC_NAME (State: $FUNC_STATE, Update: $LAST_UPDATE)"
                    VALIDATION_FAILED=true
                fi
            else
                echo "❌ Lambda function not found: $FUNC_NAME"
                VALIDATION_FAILED=true
            fi
        fi
    done
    
    echo ""
    echo "4. 🌐 Endpoint Health Validation"
    echo "-------------------------------"
    
    # Test API Gateway endpoint
    if [ -n "$API_GATEWAY_URL" ]; then
        echo "   Testing API Gateway health..."
        
        # Test create endpoint with a health check
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"original_url":"https://example.com/health-check"}' \
            "$API_GATEWAY_URL/create" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            echo "✅ API Gateway create endpoint responding: HTTP $HTTP_CODE"
        else
            echo "❌ API Gateway create endpoint failed: HTTP $HTTP_CODE"
            VALIDATION_FAILED=true
        fi
        
        # Test stats endpoint (currently returns 500 for non-existent code - this is a known issue)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/stats/nonexistent" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "500" ]; then
            echo "⚠️  API Gateway stats endpoint responding: HTTP $HTTP_CODE (should be 404 for non-existent code - known issue)"
        elif [ "$HTTP_CODE" = "404" ]; then
            echo "✅ API Gateway stats endpoint responding: HTTP $HTTP_CODE (correctly handling non-existent code)"
        elif [ "$HTTP_CODE" = "200" ]; then
            echo "✅ API Gateway stats endpoint responding: HTTP $HTTP_CODE"
        else
            echo "❌ API Gateway stats endpoint failed: HTTP $HTTP_CODE"
            VALIDATION_FAILED=true
        fi
    else
        echo "❌ API Gateway URL not available"
        VALIDATION_FAILED=true
    fi
    
    # Test CloudFront endpoint
    CF_DOMAIN=$(terraform output -raw cloudfront_distribution_domain_name 2>/dev/null || echo "")
    if [ -n "$CF_DOMAIN" ]; then
        echo "   Testing CloudFront distribution..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$CF_DOMAIN" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
            echo "✅ CloudFront distribution responding: HTTP $HTTP_CODE"
        else
            echo "❌ CloudFront distribution failed: HTTP $HTTP_CODE"
            VALIDATION_FAILED=true
        fi
    fi
    
    # Test production domain
    echo "   Testing production domain (squrl.pub)..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://squrl.pub" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Production domain responding: HTTP $HTTP_CODE"
    else
        echo "❌ Production domain failed: HTTP $HTTP_CODE"
        VALIDATION_FAILED=true
    fi
    
    echo ""
    echo "=================================================="
    
    if [ "$VALIDATION_FAILED" = true ]; then
        echo "❌ VALIDATION FAILED - Issues detected in production deployment"
        echo ""
        echo "Recommended actions:"
        echo "1. Run 'terraform plan' to check for infrastructure drift"
        echo "2. Run 'just deploy-prod' to fix any deployment issues"
        echo "3. Check AWS CloudWatch logs for Lambda function errors"
        echo "4. Verify DNS and SSL certificate configuration"
        exit 1
    else
        echo "✅ VALIDATION PASSED - Production infrastructure is healthy"
        echo ""
        echo "Production endpoints:"
        [ -n "$API_GATEWAY_URL" ] && echo "  - API: $API_GATEWAY_URL"
        [ -n "$CF_DOMAIN" ] && echo "  - CDN: https://$CF_DOMAIN"
        echo "  - Production: https://squrl.pub"
    fi

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