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

# Local Development Commands
# =============================================================================

# Start LocalStack, create DynamoDB table, and run development HTTP server
local:
    #!/usr/bin/env bash
    set -e
    echo "🚀 Starting local development environment..."

    # Start LocalStack in background
    echo "📦 Starting LocalStack..."
    docker compose up -d localstack

    # Wait for LocalStack to be ready
    echo "⏳ Waiting for LocalStack to be ready..."
    TIMEOUT=60  # 60 seconds timeout
    ELAPSED=0
    until curl -s http://localhost:4566/_localstack/health | grep -qE '"dynamodb": "(available|running)"'; do
        if [ $ELAPSED -ge $TIMEOUT ]; then
            echo "❌ Timeout waiting for LocalStack to start (${TIMEOUT}s)"
            echo "📋 Checking LocalStack logs:"
            docker compose logs localstack --tail=20
            exit 1
        fi
        echo "Waiting for LocalStack... (${ELAPSED}s/${TIMEOUT}s)"
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done

    # Setup DynamoDB table
    echo "🗄️  Setting up DynamoDB table..."
    ./scripts/setup-local-dynamodb.sh

    # Build development server
    echo "🔨 Building development server..."
    cargo build --bin dev-server

    # Start development HTTP server
    echo "⚡ Starting development HTTP server..."

    # Set environment variables for the development server
    export DYNAMODB_TABLE_NAME=squrl_urls_local
    export AWS_ENDPOINT_URL=http://localhost:4566
    export AWS_REGION=us-east-1
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export SHORT_URL_BASE=http://localhost:3000
    export RUST_LOG=info

    # Start the development server
    cargo run --bin dev-server &
    DEV_SERVER_PID=$!

    # Save PID for cleanup
    echo $DEV_SERVER_PID > /tmp/squrl-dev-server.pid

    # Wait a moment for the server to start
    sleep 2

    echo ""
    echo "🎉 Local development environment is ready!"
    echo "📋 API endpoints available at:"
    echo "   • POST http://localhost:3000/api/create-url"
    echo "   • GET  http://localhost:3000/api/redirect/:short_code"
    echo "   • GET  http://localhost:3000/api/stats/:short_code"
    echo ""
    echo "🌐 Next steps:"
    echo "   1. Run 'just local-web' (in another terminal) to start web UI"
    echo "   2. Open http://localhost:8080 in your browser"
    echo ""
    echo "💡 Run 'just local-test' to test the endpoints"
    echo "🛑 Run 'just local-stop' to stop all services"

# Stop LocalStack and development server
local-stop:
    #!/usr/bin/env bash
    echo "🛑 Stopping local development environment..."

    # Kill development server
    if [ -f /tmp/squrl-dev-server.pid ]; then
        kill $(cat /tmp/squrl-dev-server.pid) 2>/dev/null || true
        rm /tmp/squrl-dev-server.pid
        echo "✅ Stopped development server"
    fi

    # Also kill any cargo processes that might be running
    pkill -f "cargo run --bin dev-server" 2>/dev/null || true

    # Stop LocalStack
    docker compose down
    echo "✅ Stopped LocalStack"

    echo "🏁 Local development environment stopped"

# Simple test against local HTTP endpoints
local-test:
    #!/usr/bin/env bash
    set -e
    echo "🧪 Testing local HTTP endpoints..."

    # Test create-url endpoint
    echo "📝 Testing create-url endpoint..."
    RESPONSE=$(curl -s -X POST http://localhost:3000/api/create-url \
        -H "Content-Type: application/json" \
        -d '{"original_url": "https://example.com"}')

    echo "Response: $RESPONSE"

    # Extract short_code from response
    SHORT_CODE=$(echo $RESPONSE | jq -r '.short_code' 2>/dev/null || echo "")

    if [ -n "$SHORT_CODE" ] && [ "$SHORT_CODE" != "null" ]; then
        echo "✅ create-url test passed - short_code: $SHORT_CODE"

        # Test redirect endpoint
        echo "🔗 Testing redirect endpoint..."
        REDIRECT_RESPONSE=$(curl -s -X GET http://localhost:3000/api/redirect/$SHORT_CODE)
        echo "Redirect response: $REDIRECT_RESPONSE"
        echo "✅ redirect test completed"

        # Test get-stats endpoint
        echo "📊 Testing get-stats endpoint..."
        STATS_RESPONSE=$(curl -s -X GET http://localhost:3000/api/stats/$SHORT_CODE)
        echo "Stats response: $STATS_RESPONSE"
        echo "✅ get-stats test completed"

    else
        echo "❌ create-url test failed - could not extract short_code"
        echo "Response was: $RESPONSE"
        exit 1
    fi

    echo "🎉 All tests completed!"

# Start local web server for web-ui
local-web:
    #!/usr/bin/env bash
    echo "🌐 Starting local web server for web-ui..."
    echo "📂 Serving from: $(pwd)/web-ui/"
    echo "🔗 Open: http://localhost:8080"
    echo ""
    echo "💡 Make sure you've started the backend with 'just local' first"
    echo "🛑 Press Ctrl+C to stop"
    echo ""
    cd web-ui && python3 -m http.server 8080
