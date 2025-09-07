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
    echo "4. 🌐 Direct API Gateway Health Validation"
    echo "-----------------------------------------"

    # Test API Gateway endpoint directly
    if [ -n "$API_GATEWAY_URL" ]; then
        echo "   Testing direct API Gateway health..."

        # Test create endpoint with a health check
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d '{"original_url":"https://example.com/health-check-direct"}' \
            "$API_GATEWAY_URL/create" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            echo "✅ Direct API Gateway create endpoint: HTTP $HTTP_CODE"
        else
            echo "❌ Direct API Gateway create endpoint failed: HTTP $HTTP_CODE"
            VALIDATION_FAILED=true
        fi

        # Test stats endpoint directly (currently returns 500 for non-existent code - this is a known issue)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/stats/nonexistent" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "500" ]; then
            echo "⚠️  Direct API Gateway stats endpoint: HTTP $HTTP_CODE (should be 404 for non-existent code - known issue)"
        elif [ "$HTTP_CODE" = "404" ]; then
            echo "✅ Direct API Gateway stats endpoint: HTTP $HTTP_CODE (correctly handling non-existent code)"
        elif [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Direct API Gateway stats endpoint: HTTP $HTTP_CODE"
        else
            echo "❌ Direct API Gateway stats endpoint failed: HTTP $HTTP_CODE"
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

    echo ""
    echo "5. 🌍 Public Domain Validation (What Users Actually Experience)"
    echo "-----------------------------------------------------------"

    # Test production domain root
    echo "   Testing production domain root (https://squrl.pub)..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://squrl.pub" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Production domain root responding: HTTP $HTTP_CODE"
    else
        echo "❌ Production domain root failed: HTTP $HTTP_CODE"
        VALIDATION_FAILED=true
    fi

    # Create a test short URL first for realistic testing
    echo "   Creating test URL for validation..."
    TIMESTAMP=$(date +%s)
    TEST_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"original_url\":\"https://example.com/validation-test-$TIMESTAMP\"}" \
        "https://squrl.pub/create" 2>/dev/null || echo "")

    # Extract short code from response if successful
    TEST_SHORT_CODE=""
    if [ -n "$TEST_RESPONSE" ]; then
        TEST_SHORT_CODE=$(echo "$TEST_RESPONSE" | sed -n 's/.*"short_code":"\([^"]*\)".*/\1/p' 2>/dev/null || echo "")
    fi

    # Test public create endpoint
    echo "   Testing public create endpoint (https://squrl.pub/create)..."
    CREATE_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"original_url":"https://example.com/public-validation-test"}' \
        "https://squrl.pub/create" 2>/dev/null || echo "000")

    if [ "$CREATE_HTTP_CODE" = "200" ] || [ "$CREATE_HTTP_CODE" = "201" ]; then
        echo "✅ Public create endpoint responding: HTTP $CREATE_HTTP_CODE"
    else
        echo "❌ Public create endpoint failed: HTTP $CREATE_HTTP_CODE"
        VALIDATION_FAILED=true
    fi

    # Test public stats endpoint with existing code
    if [ -n "$TEST_SHORT_CODE" ] && [ "$TEST_SHORT_CODE" != "" ]; then
        echo "   Testing public stats endpoint with existing code (https://squrl.pub/stats/$TEST_SHORT_CODE)..."
        STATS_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://squrl.pub/stats/$TEST_SHORT_CODE" 2>/dev/null || echo "000")

        if [ "$STATS_HTTP_CODE" = "200" ]; then
            echo "✅ Public stats endpoint with existing code: HTTP $STATS_HTTP_CODE"
        else
            echo "❌ Public stats endpoint with existing code failed: HTTP $STATS_HTTP_CODE"
            VALIDATION_FAILED=true
        fi
    else
        echo "⚠️  Could not create test URL, skipping stats test with existing code"
    fi

    # Test public stats endpoint with non-existent code
    echo "   Testing public stats endpoint with non-existent code (https://squrl.pub/stats/nonexistent)..."
    STATS_404_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://squrl.pub/stats/nonexistent" 2>/dev/null || echo "000")

    if [ "$STATS_404_CODE" = "404" ]; then
        echo "✅ Public stats endpoint correctly returns 404 for non-existent code: HTTP $STATS_404_CODE"
    elif [ "$STATS_404_CODE" = "500" ]; then
        echo "❌ Public stats endpoint returns 500 instead of 404: HTTP $STATS_404_CODE (THIS IS THE ISSUE WE'RE INVESTIGATING)"
        VALIDATION_FAILED=true
    else
        echo "❌ Public stats endpoint unexpected response: HTTP $STATS_404_CODE"
        VALIDATION_FAILED=true
    fi

    # Test redirect functionality if we have a test code
    if [ -n "$TEST_SHORT_CODE" ] && [ "$TEST_SHORT_CODE" != "" ]; then
        echo "   Testing public redirect functionality (https://squrl.pub/$TEST_SHORT_CODE)..."
        # Test without following redirects to check if we get a proper redirect response
        REDIRECT_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://squrl.pub/$TEST_SHORT_CODE" 2>/dev/null || echo "000")

        if [ "$REDIRECT_HTTP_CODE" = "301" ] || [ "$REDIRECT_HTTP_CODE" = "302" ]; then
            echo "✅ Public redirect functionality working: HTTP $REDIRECT_HTTP_CODE (redirect)"
        else
            echo "❌ Public redirect functionality failed: HTTP $REDIRECT_HTTP_CODE (expected 301/302)"
            VALIDATION_FAILED=true
        fi
    else
        echo "⚠️  Could not create test URL, skipping redirect test"
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
