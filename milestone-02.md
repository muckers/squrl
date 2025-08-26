# Milestone 2: API Gateway & Edge Layer Implementation

**Phase 2 (Weeks 3-4) - API & Edge Optimization**  
**Status**: In Progress  
**Branch**: milestone-02

## Overview
This milestone focuses on exposing the Lambda functions through API Gateway and optimizing global delivery with CloudFront. The service will be completely free with IP-based rate limiting for abuse prevention.

## Architecture Updates

### Target Architecture
```
┌─────────────────┐
│   CloudFront    │ ← Edge caching & rate limiting
└─────────────────┘
         │
┌─────────────────┐
│  API Gateway    │ ← REST API with rate limiting
└─────────────────┘
         │
┌─────────────────────────────────────┐
│         Lambda Functions             │
│  (create-url, redirect, analytics)   │
└─────────────────────────────────────┘
         │
┌─────────────────┐
│    DynamoDB     │
└─────────────────┘
```

## API Design (No Authentication Required)

### Endpoints

#### POST /create
Create a shortened URL
- **Rate Limit**: 100 requests/minute per IP
- **Request Body**:
  ```json
  {
    "url": "https://example.com/very/long/url",
    "custom_code": "optional-custom-code" 
  }
  ```
- **Response**:
  ```json
  {
    "short_url": "https://squrl.dev/abc123",
    "short_code": "abc123",
    "expires_at": "2026-08-26T10:00:00Z"
  }
  ```

#### GET /{short_code}
Redirect to original URL
- **Rate Limit**: 1000 requests/minute per IP
- **Response**: 301 Redirect with Location header
- **Cache**: CloudFront caches for 1 hour

#### GET /stats/{short_code}
Get click statistics
- **Rate Limit**: 100 requests/minute per IP  
- **Response**:
  ```json
  {
    "short_code": "abc123",
    "clicks": 42,
    "created_at": "2025-08-26T10:00:00Z",
    "expires_at": "2026-08-26T10:00:00Z"
  }
  ```

## Rate Limiting Strategy

### Multi-Layer Protection
1. **CloudFront (Edge)**:
   - AWS WAF rate rules: 1000 requests/5 minutes per IP
   - Geographic rate limits if needed
   - Automatic temporary IP blocking

2. **API Gateway**:
   - Usage plan without API keys
   - 100 req/sec sustained, 200 req/sec burst
   - 100K requests/day quota

3. **Lambda Throttling**:
   - Reserved concurrency limits
   - Dead letter queue for failures

### Abuse Detection Metrics
- URLs created per IP per hour
- 404 rate per IP (scanner detection)
- Malformed request patterns
- Geographic anomalies

## Implementation Plan

### Week 3: API Gateway Setup (Days 1-5)

#### Day 1-2: Core API Configuration
- [x] Create milestone-02 branch
- [ ] Create API Gateway REST API via Terraform
- [ ] Define resources and methods
- [ ] Configure Lambda integrations
- [ ] Set up stages (dev, staging, prod)

#### Day 3: Rate Limiting & Security  
- [ ] Configure usage plans (no API keys)
- [ ] Set up AWS WAF rules
- [ ] Add request validation
- [ ] Configure CORS for browsers
- [ ] Add security headers

#### Day 4-5: Testing & Documentation
- [ ] Integration testing with Lambda
- [ ] Custom domain setup
- [ ] OpenAPI specification
- [ ] Rate limit testing
- [ ] Error response formatting

### Week 4: CloudFront & Observability (Days 6-10)

#### Day 6-7: CloudFront Distribution
- [ ] Create CloudFront distribution
- [ ] Configure cache behaviors
- [ ] Set up WAF rate limiting
- [ ] Add custom error pages
- [ ] Configure security headers
- [ ] Set up failover origins

#### Day 8-9: Monitoring & Alerting
- [ ] CloudWatch dashboards:
  - API metrics dashboard
  - Abuse detection dashboard
  - Cost tracking dashboard
- [ ] CloudWatch alarms:
  - High error rates (>1%)
  - Latency (P99 > 500ms)
  - Abuse patterns
  - Cost thresholds ($50/month)
- [ ] X-Ray tracing setup
- [ ] Structured logging configuration

#### Day 10: Final Testing
- [ ] End-to-end testing
- [ ] Load testing with rate limits
- [ ] Security testing
- [ ] Documentation updates
- [ ] Runbook creation

## Terraform Module Structure

```
terraform/
├── modules/
│   ├── api_gateway/
│   │   ├── main.tf              # API Gateway resources
│   │   ├── rate_limiting.tf     # Usage plans, throttling
│   │   ├── methods.tf           # HTTP methods, integrations
│   │   ├── validators.tf        # Request validators
│   │   ├── stages.tf            # Deployment stages
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloudfront/
│   │   ├── main.tf              # CloudFront distribution
│   │   ├── waf_rules.tf         # WAF rate limiting rules
│   │   ├── cache_policies.tf    # Cache behaviors
│   │   ├── origins.tf           # Origin configuration
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf              # CloudWatch resources
│       ├── dashboards.tf        # Metric dashboards
│       ├── abuse_detection.tf   # Abuse monitoring
│       ├── alarms.tf           # CloudWatch alarms
│       ├── log_groups.tf       # Log configuration
│       ├── variables.tf
│       └── outputs.tf
```

## Testing Strategy

### Unit Tests
- API Gateway request validation
- Rate limiting logic
- Error response formatting

### Integration Tests
```rust
// tests/integration/api_test.rs
#[tokio::test]
async fn test_create_url_rate_limit() {
    // Test that 101st request in a minute gets 429
}

#[tokio::test]
async fn test_redirect_caching() {
    // Verify CloudFront caches redirect responses
}
```

### Load Testing
```yaml
# tests/load/artillery-config.yml
config:
  target: 'https://api.squrl.dev'
  phases:
    - duration: 60
      arrivalRate: 100  # 100 new users/second
scenarios:
  - name: "Create and redirect"
    flow:
      - post:
          url: "/create"
          json:
            url: "https://example.com/{{ $randomNumber }}"
      - think: 5
      - get:
          url: "/{{ short_code }}"
```

## Monitoring Dashboards

### API Performance Dashboard
- Request count by endpoint
- Latency percentiles (P50, P95, P99)
- Error rates by status code
- Geographic distribution

### Abuse Detection Dashboard  
- Top 10 IPs by request volume
- URLs created per IP (hourly)
- 404 rates by IP
- Blocked requests by WAF

### Cost Tracking Dashboard
- Lambda invocation costs
- API Gateway request costs
- CloudFront data transfer
- DynamoDB operations
- Daily spend rate

## Success Metrics

### Performance
- API Gateway latency P95 < 200ms
- CloudFront cache hit rate > 80%
- Lambda cold starts < 5% of requests
- Zero false positive rate limits

### Reliability
- 99.9% uptime for all endpoints
- Graceful degradation under load
- Clear 429 error messages
- No data loss during spikes

### Cost
- Development environment < $50/month
- Production ready for $0.001 per 1000 requests
- Predictable scaling costs

## Security Considerations

### Rate Limiting
- IP-based limits prevent single-source abuse
- Geographic distribution prevents regional attacks
- Gradual blocking (warning → throttle → block)

### Input Validation
- URL format validation
- Custom code character restrictions
- Request size limits
- Malicious payload detection

### Future Enhancements
- Optional API keys for higher limits
- CAPTCHA for suspected bots
- Machine learning abuse detection
- Proof-of-work alternative

## Rollback Plan

If issues arise:
1. CloudFront: Switch to backup distribution
2. API Gateway: Revert to previous stage
3. WAF: Disable problematic rules
4. Lambda: Use aliases for instant rollback

## Documentation Deliverables

1. **API Documentation** (`docs/api/`)
   - OpenAPI 3.0 specification
   - Example requests/responses
   - Rate limit guidelines
   - Error code reference

2. **Operational Runbooks** (`docs/runbooks/`)
   - Incident response procedures
   - Abuse mitigation steps
   - Scaling procedures
   - Cost optimization guide

## Dependencies

### External Services
- AWS API Gateway
- AWS CloudFront  
- AWS WAF
- AWS CloudWatch
- AWS X-Ray

### Internal Components
- Lambda functions (from Milestone 1)
- DynamoDB tables (from Milestone 1)
- Shared library (from Milestone 1)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DDoS attack | Service unavailable | CloudFront + WAF rate limiting |
| Abuse/spam | High costs | IP-based limits, monitoring |
| Cache poisoning | Wrong redirects | Cache key configuration |
| API Gateway limits | Throttling | Usage plans, reserved capacity |

## Next Milestones

### Milestone 3: Performance Optimization
- DynamoDB DAX caching
- Lambda provisioned concurrency
- Connection pooling
- Response compression

### Milestone 4: Global Scale
- Multi-region deployment
- DynamoDB global tables
- Route 53 geo-routing
- Edge compute optimization

### Milestone 5: Analytics & Features
- Public statistics dashboard
- URL analytics pipeline
- Custom domains
- QR code generation