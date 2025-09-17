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

# PopClip Extension Commands
# =============================================================================

# Build PopClip extension package
build-popclip:
    @echo "📦 Building PopClip extension..."
    @echo "================================"
    @cd popclip-extension && zip -r squrl.popclipextz squrl.popclipext
    @echo "✅ Extension packaged as: popclip-extension/squrl.popclipextz"

# Install PopClip extension locally (macOS only)
install-popclip: build-popclip
    @echo "🔧 Installing PopClip extension..."
    @open popclip-extension/squrl.popclipextz

# Clean PopClip extension build artifacts
clean-popclip:
    @echo "🧹 Cleaning PopClip extension artifacts..."
    @rm -f popclip-extension/squrl.popclipextz
    @echo "✅ PopClip artifacts cleaned"