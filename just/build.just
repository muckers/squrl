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