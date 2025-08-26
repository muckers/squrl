# Squrl Load Testing Suite

This directory contains Artillery.js load testing configurations for the Squrl URL shortener API. The tests validate API functionality, rate limiting behavior, and caching performance according to the milestone-02 specifications.

## Prerequisites

1. **Node.js and npm** (version 16+)
2. **Artillery** - Install globally or use local installation
   ```bash
   npm install -g artillery@2.0.0
   # OR use local installation
   npm install
   ```

## Test Configurations

### 1. Standard Load Test (`artillery-config.yml`)
**Purpose**: Test sustained 100 req/sec load as per API Gateway limits
- **Duration**: ~7 minutes (warm up + sustained load + cool down)
- **Target Rate**: 100 users/second sustained
- **Scenarios**: URL creation, redirects, stats, deduplication
- **Expected**: <200ms P95, <1% error rate

```bash
# Run standard load test
npm run test:standard

# With custom environment
API_BASE_URL=https://api.squrl.dev CLOUDFRONT_URL=https://squrl.dev artillery run artillery-config.yml
```

### 2. Burst Load Test (`burst-test.yml`)
**Purpose**: Test API Gateway burst limits (200 req/sec burst)
- **Duration**: ~2.5 minutes
- **Peak Rate**: 200-300 req/sec (intentionally exceeding limits)
- **Expected**: Rate limiting (429 responses) at high burst rates
- **Validates**: Burst capacity, rate limiting behavior, recovery

```bash
# Run burst test
npm run test:burst
```

### 3. Mixed Workload Test (`mixed-workload.yml`)
**Purpose**: Simulate realistic traffic patterns
- **Duration**: ~17 minutes
- **Traffic Pattern**: 60% redirects, 25% creates, 10% stats, 5% full lifecycle
- **Rate**: Gradual ramp from 20 to 120 req/sec
- **Validates**: Real-world usage, caching effectiveness, end-to-end flows

```bash
# Run mixed workload test
npm run test:mixed
```

### 4. WAF Limit Test (`waf-limit-test.yml`)
**Purpose**: Test CloudFront WAF rate limiting (1000/5min per IP)
- **Duration**: ~13 minutes
- **Pattern**: Gradual buildup to 1000+ requests in 5-minute window
- **Expected**: WAF blocking (403 responses) after limit exceeded
- **Validates**: WAF configuration, IP-based rate limiting, recovery

```bash
# Run WAF limit test (WARNING: May trigger blocking)
npm run test:waf
```

## Environment Variables

Set these environment variables to customize test targets:

```bash
export API_BASE_URL="https://api-dev.squrl.dev"      # API Gateway endpoint
export CLOUDFRONT_URL="https://squrl-dev.squrl.dev"  # CloudFront distribution
export TEST_ENV="dev"                                 # Environment name
```

## Running Tests

### Quick Start
```bash
# Install dependencies
npm install

# Validate configurations
npm run validate-config

# Run all standard tests (excluding WAF)
npm run test:all

# Generate detailed reports
npm run report
```

### Individual Tests
```bash
# Standard load test
artillery run artillery-config.yml

# Burst test with custom target
artillery run --target https://api.squrl.dev burst-test.yml

# Mixed workload with output
artillery run --output mixed-results.json mixed-workload.yml

# Generate HTML report from results
artillery report mixed-results.json
```

## Test Metrics

### Key Performance Indicators
- **Response Time**: P50, P95, P99 percentiles
- **Throughput**: Requests per second
- **Error Rate**: HTTP 4xx/5xx responses
- **Rate Limiting**: 429 response frequency
- **Cache Hit Rate**: CloudFront cache effectiveness

### Custom Metrics Tracked
- `create.success`, `create.rate_limited` - URL creation results
- `redirect.success`, `redirect.not_found` - Redirect performance
- `stats.success`, `stats.not_found` - Statistics endpoint
- `cache.hit`, `cache.miss` - Caching effectiveness
- `waf.blocked` - WAF blocking events
- `validation.*` - Response validation results

## Expected Test Results

### Standard Load Test
- ✅ P95 response time < 200ms
- ✅ Error rate < 1%
- ✅ Sustained 100 req/sec without significant rate limiting
- ✅ Successful URL creation and redirect flow

### Burst Test
- ✅ Initial burst handling (200 req/sec)
- ✅ Rate limiting activation at higher rates (429 responses)
- ✅ Recovery after burst period
- ⚠️ Higher error rate acceptable (up to 20%)

### Mixed Workload Test
- ✅ Realistic traffic pattern handling
- ✅ Cache hit rate > 50% for redirects
- ✅ End-to-end workflow success
- ✅ Gradual performance degradation under load

### WAF Limit Test
- ✅ Normal operation under 1000 req/5min
- ✅ WAF blocking (403) after exceeding limit
- ✅ Recovery after 5-minute window
- ⚠️ High error rate expected during blocking phase

## Troubleshooting

### Common Issues

**Connection Errors**
```bash
# Check endpoint accessibility
curl -I $API_BASE_URL/create

# Verify SSL certificates
openssl s_client -connect api.squrl.dev:443 -servername api.squrl.dev
```

**Rate Limiting Issues**
```bash
# Check current rate limit status
curl -v $API_BASE_URL/create -X POST -H "Content-Type: application/json" -d '{"url":"https://example.com"}'

# Wait for rate limit reset
sleep 60
```

**High Error Rates**
- Reduce `arrivalRate` in test configurations
- Check API Gateway and Lambda logs
- Verify infrastructure capacity
- Monitor CloudWatch dashboards

### Test Output Analysis

**Response Time Issues**
- P95 > 500ms: Check Lambda cold starts, DynamoDB performance
- High variance: Investigate caching, connection pooling
- Timeouts: Review timeout configurations, scaling settings

**Rate Limiting Analysis**
- Unexpected 429s: Review usage plan configuration
- No rate limiting: Check WAF rules, API Gateway settings
- Inconsistent limiting: Monitor across multiple test runs

**Cache Performance**
- Low hit rate: Review CloudFront cache policies
- No cache headers: Check origin response headers
- Cache misses: Verify cache key configuration

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run Load Tests
  run: |
    cd tests/load
    npm install
    npm run validate-config
    npm run test:standard
  env:
    API_BASE_URL: ${{ secrets.API_BASE_URL }}
    CLOUDFRONT_URL: ${{ secrets.CLOUDFRONT_URL }}
```

### Test Thresholds for CI
```javascript
// In package.json scripts
"test:ci": "artillery run --quiet artillery-config.yml | grep -E '(p95|errors)'"
```

## Reporting

### HTML Reports
Artillery generates comprehensive HTML reports with:
- Response time histograms
- Request rate over time
- Error rate breakdown
- Custom metric graphs

### JSON Reports
Raw data in JSON format for:
- CI/CD integration
- Custom analysis
- Long-term performance tracking
- Alerting systems

### Custom Dashboards
Results can be integrated with:
- Grafana dashboards
- CloudWatch custom metrics
- DataDog APM
- New Relic monitoring

## Safety Considerations

⚠️ **WARNING**: These tests generate significant load against your API endpoints.

### Before Running
1. Ensure you have permission to load test the target environment
2. Monitor AWS costs during testing
3. Have rollback procedures ready
4. Notify team members of testing schedule

### Rate Limiting
- Tests intentionally trigger rate limiting
- WAF tests may temporarily block your IP
- Use test environments when possible
- Coordinate with infrastructure team

### Cost Management
- Monitor Lambda invocations
- Track DynamoDB read/write units
- Watch CloudFront data transfer
- Set billing alerts before testing

## Support

For issues or questions about load testing:
1. Check test output logs
2. Review CloudWatch metrics
3. Verify infrastructure status
4. Consult team runbooks