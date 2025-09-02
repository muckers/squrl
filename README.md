# sqURL - Privacy-First Serverless URL Shortener

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org)
[![AWS Lambda](https://img.shields.io/badge/AWS-Lambda-orange.svg)](https://aws.amazon.com/lambda/)
[![Terraform](https://img.shields.io/badge/terraform-1.0+-blue.svg)](https://www.terraform.io)

> A production-ready, privacy-compliant URL shortener built with Rust and AWS serverless architecture. Currently serving live traffic at **[squrl.pub](https://squrl.pub)**.

## 🚀 Overview

sqURL is a modern URL shortener service designed with privacy, performance, and scalability at its core. Built using Rust and AWS serverless technologies, it provides enterprise-grade URL shortening capabilities while maintaining strict privacy compliance and zero PII collection.

### Key Features

✨ **Privacy-First Design**
- Zero PII collection (no IP addresses, user agents, or personal data)
- Anonymous analytics with minimal log retention (3 days)
- GDPR/CCPA compliant by design

🛡️ **Security & Protection**
- AWS WAF with intelligent rate limiting (1000 req/5min global, 500 req/5min per endpoint)
- CloudFront CDN for DDoS protection and global edge caching
- Collision-resistant ID generation using nanoid

⚡ **High Performance**
- Sub-50ms response times via AWS Lambda cold start optimization
- Global CDN distribution with edge caching
- DynamoDB with GSI for O(1) lookups and deduplication

🏗️ **Production-Ready Infrastructure**
- Serverless architecture with auto-scaling
- Infrastructure as Code with Terraform
- Comprehensive monitoring and alerting
- Multi-environment deployment (dev, staging, prod)

## 🏛️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│                 │    │                  │    │                 │
│   Web Browser   │────│   CloudFront     │────│   API Gateway   │
│                 │    │   + WAF          │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                       ┌─────────────────────────────────────────┐
                       │          Lambda Functions               │
                       ├─────────────────────────────────────────┤
                       │    create-url    │     redirect        │
                       └─────────────────────────────────────────┘
                                          │
                                          ▼
                       ┌─────────────────────────────────────────┐
                       │              DynamoDB                   │
                       │                                         │
                       │  • URLs Table (short_code PK)           │
                       │  • GSI on original_url                  │
                       │  • TTL for expiration                   │
                       │  • Click count tracking                 │
                       │                                         │
                       └─────────────────────────────────────────┘
```

### Core Components

- **🌐 CloudFront + WAF**: Global CDN with DDoS protection and rate limiting
- **🚪 API Gateway**: RESTful API with request validation and CORS
- **⚡ Lambda Functions**: 2 serverless functions (create-url, redirect)
- **🗄️ DynamoDB**: NoSQL database with GSI for deduplication and click tracking
- **📈 CloudWatch**: Monitoring, alerting, and operational dashboards

## 🛠️ Development Setup

### Prerequisites

```bash
# Core dependencies
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh  # Rust
pip install cargo-lambda                                         # Lambda tooling
cargo install just                                              # Task runner
pip install awscli-local[ver1]                                 # LocalStack CLI

# AWS & Infrastructure
aws configure                                                    # AWS CLI
terraform -version                                              # Terraform 1.0+
docker compose                                                  # LocalStack
```

### Local Development

1. **Clone and build**:
```bash
git clone https://github.com/your-org/squrl.git
cd squrl
just build
```

2. **Start local infrastructure**:
```bash
# Start LocalStack with DynamoDB
just local-infra
```

3. **Run Lambda functions locally** (in separate terminals):
```bash
# Terminal 1: Create URL function (port 9001)
just run-local-create-url

# Terminal 2: Redirect function (port 9002)
just run-local-redirect
```

4. **Test the local API**:
```bash
# Create a short URL
curl -X POST http://localhost:9001/2015-03-31/functions/function/invocations \
  -H "Content-Type: application/json" \
  -d '{"body": "{\"original_url\": \"https://example.com\"}"}'

# Test redirect
curl -I http://localhost:9002/2015-03-31/functions/function/invocations \
  -H "Content-Type: application/json" \
  -d '{"pathParameters": {"short_code": "YOUR_SHORT_CODE"}}'
```

## 🚢 Deployment

### Environment Management

The project supports multiple environments with Terraform:

```bash
# Deploy to development environment
just deploy-dev

# Deploy to production environment
just deploy-prod

# Check deployment status
just dev-status
```

### Infrastructure Components

Each environment includes:
- **Lambda Functions**: Auto-scaling serverless compute
- **DynamoDB Table**: With on-demand billing and global secondary index
- **API Gateway**: RESTful API with request validation
- **CloudFront Distribution**: Global CDN with custom domain
- **WAF Web ACL**: Rate limiting and DDoS protection
- **CloudWatch**: Monitoring, logging, and alerting

### Manual Terraform Deployment

```bash
# Initialize and deploy to production
cd terraform/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## 📚 API Reference

### Create Short URL

```http
POST /create
Content-Type: application/json

{
  "original_url": "https://example.com/very/long/url"
}
```

**Response:**
```json
{
  "short_code": "abc123",
  "original_url": "https://example.com/very/long/url",
  "short_url": "https://squrl.pub/abc123",
  "created_at": "2025-08-30T12:00:00Z",
  "expires_at": "2026-08-30T12:00:00Z"
}
```

### Redirect to Original URL

```http
GET /{short_code}
```

**Response:** `301 Redirect` to original URL with caching headers

### Get URL Statistics

```http
GET /stats/{short_code}
```

**Response:**
```json
{
  "short_code": "abc123",
  "original_url": "https://example.com/very/long/url",
  "click_count": 42,
  "created_at": "2025-08-30T12:00:00Z"
}
```

### Example Usage

```bash
# Create short URL
curl -X POST https://squrl.pub/create \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://github.com/your-org/squrl"}'

# Use the short URL (redirect)
curl -I https://squrl.pub/abc123

# Get statistics
curl https://squrl.pub/stats/abc123
```

## 🧪 Testing

### Unit Tests

```bash
# Run all unit tests
just test

# Run tests with coverage
cargo test --all-features --workspace
```

### Integration Tests

```bash
# Test against development environment
just test-integration dev

# Test against production (with confirmation)
just test-integration prod

# Test specific functionality
just test-api dev
just test-caching dev
```

### Load Testing

```bash
# Install testing dependencies
just test-install-deps

# Run standard load test
just test-load dev

# Run specific test types
just test-load-type standard dev
just test-load-type burst staging    # Tests rate limiting
just test-load-type waf-oha prod    # WAF stress test (Rust-based)
```

### WAF & Rate Limiting Tests

```bash
# Test WAF rate limiting (will trigger blocks)
just test-waf-oha staging

# Monitor WAF logs during testing
aws logs tail /aws/wafv2/squrl-cloudfront-prod --follow
```

## 📊 Monitoring & Operations

### Health Monitoring

The production deployment includes comprehensive monitoring:

- **CloudWatch Dashboards**: Service health, API performance, and cost tracking
- **Alerts**: Lambda errors, DynamoDB throttling, API Gateway 5XX errors
- **Privacy-Compliant Metrics**: Anonymous analytics without PII

### Key Metrics

```bash
# Check service status
just dev-status

# View recent logs
just dev-logs                    # All services
just dev-logs-create-url        # Specific function
just dev-logs-redirect

# Database operations
just dev-db-scan                # View all URLs
just dev-db-get abc123          # Get specific URL
```

### Production Monitoring

- **Uptime**: 99.9%+ availability with Lambda auto-scaling
- **Performance**: <50ms P95 response times
- **Privacy**: Zero PII collection, 3-day log retention
- **Cost**: ~$10/month for moderate traffic loads

## 🔒 Security & Privacy

### Privacy Features

- ✅ **Zero PII Collection**: No IP addresses, user agents, or personal data
- ✅ **Anonymous Analytics**: Only short codes and timestamps
- ✅ **Minimal Retention**: 3-day log retention policy
- ✅ **GDPR Compliant**: Privacy by design architecture

### Security Measures

- 🛡️ **WAF Protection**: 1000 req/5min global rate limit
- 🔐 **TLS Encryption**: All traffic encrypted in transit
- 🚫 **DDoS Protection**: CloudFront shield and auto-scaling
- 🔍 **Input Validation**: Strict URL validation and sanitization

### Rate Limiting

| Endpoint | Rate Limit | Window |
|----------|------------|--------|
| Global | 1000 requests | 5 minutes |
| `/create` | 500 requests | 5 minutes |
| `/{short_code}` | Unlimited | - |

## ⚡ Performance

### Benchmarks

- **Cold Start**: <200ms Lambda initialization
- **Warm Request**: <50ms P95 response time
- **Throughput**: 1000+ RPS sustained
- **Availability**: 99.9%+ uptime SLA

### Load Test Results

```bash
# Generate load test report
just test-load-report

# Recent production metrics:
# - Requests: 10,000/hour peak
# - Errors: <0.1% error rate
# - Latency: P95 <50ms, P99 <100ms
```

## 🗂️ Project Structure

```
squrl/
├── lambda/                    # AWS Lambda functions
│   ├── create-url/           # URL creation service
│   └── redirect/             # URL redirection service
├── shared/                   # Common Rust library
│   ├── models.rs            # Data structures
│   ├── dynamodb.rs          # Database operations
│   ├── validation.rs        # Input validation
│   └── error.rs             # Error handling
├── terraform/               # Infrastructure as Code
│   ├── environments/        # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/             # Reusable Terraform modules
├── web-ui/                  # Static web interface
│   ├── index.html          # Main web interface
│   └── error.html          # Error page
├── tests/                   # Testing suite
│   ├── integration/        # API integration tests
│   └── load/              # Load testing configs
├── scripts/               # Deployment and utility scripts
├── justfile              # Task automation (replaces Makefile)
└── Cargo.toml            # Rust workspace configuration
```

## 🚀 Production Deployment

### Live Service

**sqURL is currently live at [squrl.pub](https://squrl.pub)**

- Production environment with global CloudFront distribution
- Privacy-compliant analytics and monitoring
- WAF protection with intelligent rate limiting
- 99.9%+ uptime with auto-scaling Lambda functions

### Deployment Pipeline

```bash
# 1. Build Lambda functions
just build

# 2. Run integration tests
just test-integration staging

# 3. Deploy to production
just deploy-prod

# 4. Verify deployment
just test-connectivity prod
just test-api prod
```

### Cost Optimization

- **Lambda**: ~$5/month (1M invocations)
- **DynamoDB**: ~$2/month (on-demand billing)
- **CloudFront**: ~$1/month (1GB transfer)
- **Other AWS Services**: ~$2/month
- **Total**: ~$10/month for moderate usage

## 🤝 Contributing

### Development Workflow

1. **Fork and clone** the repository
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** and add tests
4. **Run the test suite**: `just test-all dev`
5. **Submit a pull request** with a clear description

### Code Standards

- **Rust**: Follow `rustfmt` and `clippy` recommendations
- **Tests**: Maintain >80% code coverage
- **Documentation**: Update README for API changes
- **Privacy**: Ensure no PII collection in new features

### Testing Requirements

```bash
# Run full test suite before PR
just test                      # Unit tests
just lint                      # Linting
just fmt                       # Code formatting
just test-integration dev      # Integration tests
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Rust](https://www.rust-lang.org/) and [AWS Lambda](https://aws.amazon.com/lambda/)
- Infrastructure managed with [Terraform](https://www.terraform.io/)
- Load testing powered by [Artillery](https://artillery.io/) and [oha](https://github.com/hatoo/oha)
- Privacy compliance inspired by GDPR and CCPA requirements

---

**🔗 Start shortening URLs today at [squrl.pub](https://squrl.pub)**

For questions, issues, or contributions, please visit our [GitHub repository](https://github.com/your-org/squrl) or open an issue.
