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