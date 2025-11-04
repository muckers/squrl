#!/bin/bash

# Script to clear all URLs from the staging DynamoDB table
# Usage: ./scripts/clear-staging-db.sh

set -e

ENVIRONMENT="dev"
TABLE_NAME="squrl-urls-${ENVIRONMENT}"
REGION="us-east-1"

echo "🐿️ Squrl Database Cleaner"
echo "=========================="
echo "Environment: ${ENVIRONMENT}"
echo "Table: ${TABLE_NAME}"
echo "Region: ${REGION}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if table exists
echo "🔍 Checking if table exists..."
if ! aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" &> /dev/null; then
    echo "❌ Table '$TABLE_NAME' not found in region '$REGION'"
    exit 1
fi

echo "✅ Table found!"
echo ""

# Count current items
echo "📊 Counting current items..."
ITEM_COUNT=$(aws dynamodb scan \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --select "COUNT" \
    --query "Count" \
    --output text)

echo "Current items in table: $ITEM_COUNT"
echo ""

if [ "$ITEM_COUNT" -eq 0 ]; then
    echo "🎉 Table is already empty!"
    exit 0
fi

# Confirmation prompt
echo "⚠️  WARNING: This will delete ALL $ITEM_COUNT URLs from the staging database!"
echo "This action cannot be undone."
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "❌ Operation cancelled."
    exit 0
fi

echo ""
echo "🗑️  Starting database cleanup..."

# First, collect all short codes for CloudFront invalidation BEFORE deleting
echo "📥 Collecting short codes for CloudFront cache invalidation..."
SHORT_CODES_JSON=$(aws dynamodb scan \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --projection-expression "short_code" \
    --output json)

CLOUDFRONT_PATHS=""
if [ "$(echo "$SHORT_CODES_JSON" | jq '.Items | length')" -gt 0 ]; then
    CLOUDFRONT_PATHS=$(echo "$SHORT_CODES_JSON" | jq -r '.Items[].short_code.S | "/" + .' | head -n 100)
fi

# Now delete all items
echo "📥 Scanning table and deleting items..."
echo "$SHORT_CODES_JSON" | jq -r '.Items[].short_code.S' | \
while read -r short_code; do
    if [ -n "$short_code" ]; then
        echo "   Deleting: $short_code"
        aws dynamodb delete-item \
            --table-name "$TABLE_NAME" \
            --region "$REGION" \
            --key '{"short_code": {"S": "'$short_code'"}}' \
            --output text > /dev/null
    fi
done

# Invalidate CloudFront cache for the deleted URLs
if [ -n "$CLOUDFRONT_PATHS" ]; then
    echo ""
    echo "☁️  Invalidating CloudFront cache for deleted URLs..."
    CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"  # Set via environment variable

    if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        echo "   Creating CloudFront invalidation for $(echo "$CLOUDFRONT_PATHS" | wc -l | tr -d ' ') paths..."
        echo "$CLOUDFRONT_PATHS" | tr '\n' ' ' | xargs aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --paths > /dev/null 2>&1 && echo "   ✅ CloudFront invalidation created successfully" || echo "   ⚠️  CloudFront invalidation may have failed (this is non-critical)"
    else
        echo "   ⚠️  CLOUDFRONT_DISTRIBUTION_ID not set, skipping CloudFront invalidation"
    fi
else
    echo ""
    echo "☁️  No CloudFront invalidation needed (no URLs found)"
fi

echo ""
echo "🔍 Verifying cleanup..."
NEW_COUNT=$(aws dynamodb scan \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --select "COUNT" \
    --query "Count" \
    --output text)

echo "Items remaining: $NEW_COUNT"

if [ "$NEW_COUNT" -eq 0 ]; then
    echo ""
    echo "🎉 Database cleanup completed successfully!"
    echo "All URLs have been removed from the staging database."
else
    echo ""
    echo "⚠️  Warning: $NEW_COUNT items still remain. You may need to run this script again."
fi

echo ""
echo "✨ Done!"