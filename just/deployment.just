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