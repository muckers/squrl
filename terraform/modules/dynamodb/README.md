# DynamoDB Module

This Terraform module creates and configures an Amazon DynamoDB table for the Squrl URL shortener service, optimized for storing and retrieving shortened URLs.

## Features

- **Pay-Per-Request Billing:** No capacity planning required - scales automatically with demand
- **Global Secondary Index:** Enables URL deduplication by checking if a URL already exists
- **TTL Support:** Automatic expiration of URLs based on `expires_at` timestamp
- **Point-in-Time Recovery:** Enabled for data protection and recovery
- **Server-Side Encryption:** Data encrypted at rest using AWS managed keys
- **Optimized Schema:** Primary key on `short_code` for fast lookups

## Table Schema

The DynamoDB table is structured with the following attributes:

- **Primary Key:**
  - `short_code` (String) - Partition key for O(1) lookups

- **Global Secondary Index:**
  - `original_url_index` - Hash key on `original_url` for deduplication checks

- **Additional Attributes:**
  - `original_url` - The full URL to redirect to
  - `created_at` - Timestamp when the URL was created
  - `expires_at` - TTL attribute for automatic expiration
  - `click_count` - Number of times the URL has been accessed
  - `custom_code` - Optional custom short code provided by user

## Usage

```hcl
module "dynamodb" {
  source = "./modules/dynamodb"

  table_name  = "squrl-urls-dev"
  environment = "dev"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| table_name | Name of the DynamoDB table | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| table_name | Name of the DynamoDB table |
| table_arn | ARN of the DynamoDB table |

## Performance Characteristics

- **Read Performance:** O(1) lookups using partition key (short_code)
- **Write Performance:** Consistent single-digit millisecond latency
- **Deduplication:** GSI enables efficient checking for existing URLs
- **Auto-scaling:** Pay-per-request mode handles traffic spikes automatically

## Cost Optimization

The module uses several cost optimization strategies:

1. **Pay-Per-Request Billing:** Only pay for actual usage, no idle capacity costs
2. **TTL Enabled:** Automatic deletion of expired items reduces storage costs
3. **Efficient Indexes:** Only one GSI to minimize additional costs
4. **No Reserved Capacity:** Ideal for variable or unpredictable traffic patterns

## Data Protection

- **Point-in-Time Recovery:** Restore table to any point within last 35 days
- **Server-Side Encryption:** All data encrypted at rest
- **TTL Cleanup:** Expired URLs automatically removed within 48 hours
- **IAM Policies:** Fine-grained access control via Lambda IAM roles

## Monitoring

The table automatically publishes metrics to CloudWatch:

- **ConsumedReadCapacityUnits** - Read usage tracking
- **ConsumedWriteCapacityUnits** - Write usage tracking
- **UserErrors** - Client-side errors (e.g., validation failures)
- **SystemErrors** - Server-side errors
- **ThrottledRequests** - Rate limiting events (rare with pay-per-request)

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Appropriate IAM permissions for DynamoDB table creation and management

## Notes

- The table is designed for the Squrl URL shortener service
- TTL deletion happens asynchronously within 48 hours of expiration
- Global Secondary Index projections include all attributes for flexibility
- Pay-per-request mode is ideal for unpredictable traffic patterns
- Point-in-time recovery adds minimal cost but provides significant protection