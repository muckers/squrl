#!/bin/bash

# Setup DynamoDB table for local development with LocalStack
# This script creates the urls table with the same structure as production

set -e

ENDPOINT_URL="http://localhost:4566"
TABLE_NAME="squrl_urls_local"
REGION="us-east-1"

echo "Setting up DynamoDB table for local development..."

# Create the URLs table (skip if already exists)
echo "Creating table $TABLE_NAME..."
aws dynamodb create-table \
    --table-name $TABLE_NAME \
    --attribute-definitions \
        AttributeName=short_code,AttributeType=S \
        AttributeName=original_url,AttributeType=S \
    --key-schema \
        AttributeName=short_code,KeyType=HASH \
    --global-secondary-indexes \
        IndexName=original_url_index,KeySchema='[{AttributeName=original_url,KeyType=HASH}]',Projection='{ProjectionType=ALL}' \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url $ENDPOINT_URL \
    --region $REGION 2>/dev/null || echo "Table $TABLE_NAME already exists, skipping creation..."

echo "Waiting for table to become active..."
aws dynamodb wait table-exists --table-name $TABLE_NAME --endpoint-url $ENDPOINT_URL --region $REGION

# Update TTL settings
echo "Configuring TTL on expires_at field..."
aws dynamodb update-time-to-live \
    --table-name $TABLE_NAME \
    --time-to-live-specification Enabled=true,AttributeName=expires_at \
    --endpoint-url $ENDPOINT_URL \
    --region $REGION

echo "✅ DynamoDB table '$TABLE_NAME' created successfully!"
echo "Table details:"
aws dynamodb describe-table --table-name $TABLE_NAME --endpoint-url $ENDPOINT_URL --region $REGION --query 'Table.{Name:TableName,Status:TableStatus,ItemCount:ItemCount}'
