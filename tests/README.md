# Squrl Testing Suite

This directory contains comprehensive integration and load tests for the Squrl URL shortener API, validating the complete API Gateway + CloudFront + Lambda stack according to milestone-02 specifications.

## Test Organization

### 📁 `/integration/` - Rust Integration Tests
Production-ready Rust integration tests that validate:
- **API Functionality**: POST /create, GET /{short_code}, GET /stats/{short_code}
- **Rate Limiting**: API Gateway (100 req/sec sustained, 200 burst) and WAF (1000/5min)  
- **Caching Behavior**: CloudFront cache hit/miss verification and TTL validation
- **Error Handling**: Invalid requests, malformed JSON, non-existent codes

### 📁 `/load/` - Artillery Load Tests
Artillery.js load testing configurations that simulate:
- **Standard Load**: 100 users/second sustained load
- **Burst Testing**: Rate limiting validation with burst traffic
- **Mixed Workload**: Realistic traffic patterns (create + redirect + stats)
- **WAF Limits**: 1000 requests/5min blocking verification

## Quick Start

### Prerequisites
1. **Rust toolchain** (for integration tests)
2. **Node.js 16+** and **npm** (for load tests)
3. **curl** and **jq** (for connectivity tests)

### Installation
```bash
# Install all testing dependencies
just test-install-deps

# Or install separately:
cd tests/integration && cargo build --release
cd ../load && npm install
```

### Basic Usage
```bash
# Test connectivity first
just test-connectivity dev

# Run integration tests
just test-integration dev

# Run load tests (with warning prompts)
just test-load dev

# Run comprehensive test suite
just test-all dev
```

## Available Test Commands

### 🧪 Integration Tests
```bash
# Full integration test suite
just test-integration [ENV]

# Individual test categories  
just test-api [ENV]           # API functionality only
just test-caching [ENV]       # CloudFront caching behavior
just test-rate-limits [ENV]   # Rate limiting (WARNING: high load)
```

### 🚀 Load Tests
```bash
# Standard load test
just test-load [ENV]

# Specific test types
just test-load-type standard [ENV]    # 100 req/sec sustained
just test-load-type burst [ENV]       # Burst rate limiting
just test-load-type mixed [ENV]       # Mixed workload patterns
just test-load-type waf [ENV]         # WAF blocking (WARNING)

# Generate reports from previous runs
just test-load-report
```

### 🔧 Utility Commands
```bash
# Test basic connectivity
just test-connectivity [ENV]

# Install test dependencies
just test-install-deps

# Run everything (unit + integration + load)
just test-all [ENV]
```

## Environment Targets

| Environment | API Gateway | CloudFront Distribution |
|-------------|-------------|------------------------|
| `dev` (default) | `https://api-dev.squrl.dev` | `https://squrl-dev.squrl.dev` |
| `staging` | `https://api-staging.squrl.dev` | `https://squrl-staging.squrl.dev` |
| `prod` | `https://api.squrl.dev` | `https://squrl.dev` |

### Environment Variables
You can override URLs by setting environment variables:
```bash
export API_BASE_URL="https://custom-api.example.com"
export CLOUDFRONT_URL="https://custom-cdn.example.com"
```

## Test Specifications

### Integration Tests Validate

#### API Functionality ✅
- **URL Creation**: POST /create with and without custom codes
- **URL Deduplication**: Same URL returns same short code
- **Redirects**: GET /{short_code} returns proper 301/302
- **Statistics**: GET /stats/{short_code} returns click data
- **Error Handling**: 400/404/429 responses with proper format

#### Rate Limiting ✅  
- **API Gateway Sustained**: 100 requests/second limit
- **API Gateway Burst**: 200 requests/second burst capacity
- **Per-Endpoint Limits**: Different limits for create vs redirect
- **WAF Rules**: 1000 requests per 5-minute window per IP
- **Recovery Behavior**: Rate limit reset after time window

#### Caching Behavior ✅
- **Cache Miss → Hit**: First request misses, subsequent hits
- **TTL Validation**: Age headers increment correctly  
- **Endpoint-Specific**: Redirects cached, stats may vary
- **Cache Headers**: Proper CloudFront headers present
- **Performance**: Cached responses are faster

### Load Tests Validate

#### Standard Load Test ✅
- **Target**: 100 users/second for 5 minutes
- **Scenarios**: 70% creates, 15% custom codes, 10% dedup, 5% stats
- **Success Criteria**: P95 < 200ms, error rate < 1%

#### Burst Test ✅  
- **Target**: 200-300 requests/second bursts
- **Expected**: Rate limiting (429 responses) at high rates
- **Validation**: Recovery after burst period

#### Mixed Workload Test ✅
- **Pattern**: 60% redirects, 25% creates, 10% stats, 5% lifecycle
- **Duration**: 17 minutes with gradual ramp up
- **Validation**: Real-world usage patterns, cache effectiveness

#### WAF Limit Test ⚠️
- **Target**: 1000+ requests in 5-minute window  
- **Expected**: WAF blocking (403 responses) after limit
- **Warning**: May temporarily block your IP address

## Test Results and Metrics

### Key Performance Indicators
- **Response Time**: P50, P95, P99 percentiles
- **Throughput**: Requests per second sustained
- **Error Rate**: HTTP 4xx/5xx response percentage
- **Cache Hit Rate**: CloudFront cache effectiveness
- **Rate Limit Behavior**: 429 response patterns

### Expected Results

#### ✅ Passing Criteria
- **API Gateway P95** < 200ms
- **CloudFront Cache Hit Rate** > 80%
- **Standard Load Error Rate** < 1%
- **Rate Limiting Activation** at expected thresholds
- **WAF Blocking** after 1000 requests/5min

#### ⚠️ Acceptable Variations
- **Burst Test Error Rate** up to 20% (due to intentional rate limiting)
- **WAF Test Error Rate** up to 50% (during blocking phase)
- **Cold Start Impact** on first requests after deployment

## Safety and Considerations

### ⚠️ Load Testing Warnings
- **API Costs**: Load tests generate AWS charges for Lambda, API Gateway, DynamoDB
- **Rate Limiting**: Tests intentionally trigger rate limits and may affect other users
- **WAF Blocking**: WAF tests may temporarily block your IP address
- **Production**: Extra confirmation required for production load testing

### 🛡️ Safety Measures
- **Environment Isolation**: Use dev/staging for heavy testing
- **Confirmation Prompts**: Dangerous tests require explicit confirmation
- **Gradual Ramp**: Load tests start small and increase gradually
- **Monitoring**: Watch CloudWatch dashboards during testing

### 💰 Cost Management
- **Monitor Usage**: Track Lambda invocations, DynamoDB operations
- **Set Alerts**: AWS billing alerts recommended before load testing
- **Time Limits**: Tests have built-in duration limits
- **Resource Cleanup**: Clean up test data after completion

## Troubleshooting

### Common Issues

#### Connection Problems
```bash
# Verify endpoints are accessible
curl -I https://api-dev.squrl.dev/create
curl -I https://squrl-dev.squrl.dev

# Check DNS resolution
nslookup api-dev.squrl.dev
```

#### Rate Limiting Issues
```bash
# Check if you're currently rate limited
curl -v https://api-dev.squrl.dev/create \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/test"}'

# Wait for rate limit reset (varies by limit type)
sleep 60  # API Gateway limits
sleep 300 # WAF limits
```

#### Integration Test Failures
```bash
# Run with debug logging
RUST_LOG=debug just test-api dev

# Check individual test components
just test-connectivity dev
```

#### Load Test Issues
```bash
# Validate Artillery configuration
cd tests/load && npm run validate-config

# Check Node.js and Artillery versions
node --version
npx artillery --version

# Run smaller test first
# Edit artillery-config.yml to reduce arrivalRate
```

### Performance Issues

#### High Response Times
- **Check Lambda Cold Starts**: Monitor CloudWatch Lambda metrics
- **DynamoDB Throttling**: Check DynamoDB capacity and throttling
- **Network Latency**: Test from different geographic locations

#### Low Cache Hit Rates
- **Verify Cache Headers**: Check CloudFront cache policies
- **Cache Key Configuration**: Ensure proper cache key setup
- **TTL Settings**: Review cache TTL configurations

#### Rate Limiting Problems
- **Usage Plan Settings**: Verify API Gateway usage plans
- **WAF Rule Configuration**: Check CloudFront WAF rules
- **IP Address Issues**: Test from different IP addresses

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: just test-install-deps
        
      - name: Run integration tests
        run: just test-integration dev
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
          CLOUDFRONT_URL: ${{ secrets.CLOUDFRONT_URL }}
          
      # Only run load tests on main branch
      - name: Run load tests
        if: github.ref == 'refs/heads/main'
        run: just test-load-type standard dev
```

### Performance Monitoring Integration
```bash
# Export metrics to monitoring systems
# Results can be integrated with:
# - Grafana dashboards
# - DataDog APM  
# - New Relic monitoring
# - Custom CloudWatch metrics
```

## Development and Contribution

### Adding New Tests

#### Integration Tests (Rust)
```rust
// Add to tests/integration/src/new_tests.rs
#[tokio::test]
async fn test_new_functionality() {
    let config = TestConfig::default();
    let mut client = TestClient::new(config);
    
    // Test implementation
}
```

#### Load Tests (Artillery)
```yaml
# Add to tests/load/new-test.yml
config:
  target: "{{ $processEnvironment.API_BASE_URL }}"
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "New Test Scenario"
    flow:
      - post:
          url: "/create"
          json:
            url: "https://example.com/new-test"
```

### Test Maintenance
- **Regular Updates**: Keep Artillery and Rust dependencies updated
- **Environment Sync**: Update test URLs when environments change  
- **Threshold Adjustment**: Update performance thresholds as system improves
- **Documentation**: Keep test documentation current with API changes

## Support and Debugging

### Debug Information
```bash
# Enable debug logging for integration tests
RUST_LOG=debug just test-integration dev

# Enable verbose Artillery output
cd tests/load && DEBUG=* npm run test:standard

# Check test configurations
just test-connectivity dev
```

### Log Analysis
- **CloudWatch Logs**: Monitor Lambda function logs during testing
- **API Gateway Logs**: Check API Gateway access logs for request patterns
- **CloudFront Logs**: Analyze CloudFront distribution logs for caching behavior

### Getting Help
1. **Check test output** for specific error messages
2. **Review CloudWatch dashboards** for infrastructure issues
3. **Validate configuration** with connectivity tests
4. **Consult team runbooks** for known issues and solutions

---

## Summary

This comprehensive testing suite ensures the Squrl URL shortener API meets all milestone-02 specifications:

✅ **API Gateway + CloudFront + Lambda stack validation**  
✅ **Rate limiting behavior (100 req/sec sustained, 200 burst, 1000/5min WAF)**  
✅ **Caching performance and TTL validation**  
✅ **End-to-end functionality testing**  
✅ **Load testing with realistic traffic patterns**  
✅ **Production-ready error handling and edge cases**  

The testing suite provides confidence in the system's performance, reliability, and scalability while maintaining cost efficiency and operational safety.