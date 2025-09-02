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