#!/bin/sh
# Test script to verify URL expiration functionality

set -e

# API Endpoint - set via environment variable
# Example: export SQURL_API_ENDPOINT=https://YOUR_API_GW_ID.execute-api.us-east-1.amazonaws.com/v1
if [ -z "$SQURL_API_ENDPOINT" ]; then
    echo "Error: SQURL_API_ENDPOINT environment variable not set"
    echo "Please set it to your API Gateway endpoint"
    echo "Example: export SQURL_API_ENDPOINT=https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/v1"
    exit 1
fi

API_ENDPOINT="$SQURL_API_ENDPOINT"

echo "Testing URL expiration functionality..."
echo "======================================="

# Create a URL with 1 hour TTL
echo "1. Creating a short URL with 1-hour TTL..."
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"original_url":"https://example.com/test-expiration", "ttl_hours":1}' \
    "${API_ENDPOINT}/create")

SHORT_CODE=$(echo "$RESPONSE" | jq -r '.short_code')
EXPIRES_AT=$(echo "$RESPONSE" | jq -r '.expires_at')

if [ -z "$SHORT_CODE" ] || [ "$SHORT_CODE" = "null" ]; then
    echo "Error: Failed to create URL"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "Created short code: $SHORT_CODE"
echo "Expires at: $EXPIRES_AT"
echo ""

# Test that the URL works immediately
echo "2. Testing redirect immediately after creation..."
REDIRECT_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
    "${API_ENDPOINT}/${SHORT_CODE}")

HTTP_CODE=$(echo "$REDIRECT_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✓ Redirect works (HTTP $HTTP_CODE)"
else
    echo "✗ Unexpected response code: HTTP $HTTP_CODE"
    echo "Response body:"
    echo "$REDIRECT_RESPONSE" | head -n-1
fi

echo ""
echo "Test complete!"
echo ""
echo "Note: To test actual expiration:"
echo "1. Create a URL with ttl_hours:0 (if supported for immediate expiration)"
echo "2. Or wait for the TTL period to pass"
echo "3. Then try to access the URL - it should return HTTP 410 (Gone)"