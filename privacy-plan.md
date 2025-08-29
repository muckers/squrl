# Comprehensive Anonymization Plan for URL Shortener Service

## Current Privacy Issues Identified

1. **IP Address Collection**: Client IPs are extracted and stored in analytics events
2. **User-Agent & Referer Logging**: Browser fingerprinting data collected
3. **API Gateway Access Logs**: Contains sourceIp and userAgent
4. **CloudWatch Logs**: Various logs contain traceable information
5. **DynamoDB Model**: Has creator_ip field (currently unused but available)
6. **WAF Logs**: Contains IP addresses of blocked requests

## Implementation Plan

### 1. Lambda Functions - Remove PII Collection

- **redirect/src/main.rs**: 
  - Remove client_ip, user_agent, referer extraction from API Gateway events
  - Modify AnalyticsEvent to only include non-identifiable data (short_code, timestamp, anonymous metrics)
- **analytics/src/main.rs**: 
  - Remove logging of any PII from analytics processing
- **create-url/src/main.rs**: 
  - Ensure creator_ip remains None (already implemented)

### 2. Shared Models - Anonymize Data Structures

- **shared/src/models.rs**:
  - Remove or make optional: client_ip, user_agent, referer, country, city from AnalyticsEvent
  - Remove creator_ip field from UrlItem struct entirely

### 3. API Gateway Configuration

- **terraform/modules/api_gateway/stages.tf**:
  - Disable access logging OR create custom log format without sourceIp and userAgent
  - Keep only necessary fields: requestTime, httpMethod, status, responseTime

### 4. WAF Configuration (Maintaining Rate Limiting)

- **No changes needed!** WAF operates at edge level
- WAF can still use IP addresses for rate limiting without logging them
- Configure WAF logging to minimal or disable entirely
- If WAF logging is required, configure log retention to minimum (1 day)

### 5. CloudWatch Logs

- **terraform/modules/monitoring/log_groups.tf**:
  - Set minimal retention periods (1-3 days max)
  - Configure log filters to exclude PII
- **Lambda log groups**: 
  - Remove info! and debug! statements that log request details

### 6. Anonymous Analytics Strategy

Instead of tracking individuals, track:
- Total click counts per short URL
- Timestamp patterns (hourly/daily aggregates)
- HTTP status codes distribution
- Response time metrics
- Error rates

### 7. Privacy-Preserving Features to Add

- Implement hash-based duplicate detection instead of IP-based
- Use session tokens with short TTL for rate limiting at application level
- Add privacy policy endpoint
- Implement GDPR-compliant data deletion API

## Key Technical Details

### WAF Rate Limiting Without Logging
- WAF performs rate limiting at CloudFront edge locations
- IP addresses are used in-memory for rate calculations
- No need to store IPs in logs or databases
- Rate limiting still functions perfectly

### Alternative Abuse Detection
- Use behavioral patterns (rapid sequential requests)
- Implement CAPTCHA for suspicious patterns
- Hash-based fingerprinting without storing raw data

## Files to Modify

1. `lambda/redirect/src/main.rs`
2. `lambda/analytics/src/main.rs`
3. `lambda/create-url/src/main.rs`
4. `shared/src/models.rs`
5. `terraform/modules/api_gateway/stages.tf`
6. `terraform/modules/cloudfront/waf_rules.tf`
7. `terraform/modules/monitoring/log_groups.tf`

## Testing Strategy

1. Verify WAF rate limiting still works with curl/load testing
2. Confirm no PII in CloudWatch logs
3. Test analytics pipeline with anonymized events
4. Validate API Gateway logs contain no traceable data

## Privacy Principles

- **Data Minimization**: Collect only what's necessary for service operation
- **Purpose Limitation**: Use data only for stated purposes
- **Storage Limitation**: Minimize retention periods
- **Anonymization**: Remove all personally identifiable information
- **Transparency**: Clear privacy policy and user controls