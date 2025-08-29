# VPC Endpoints Module

A comprehensive Terraform module for creating VPC endpoints to provide private access to AWS services for Lambda functions in the Squrl URL shortener project.

## Overview

This module provides secure, private connectivity to AWS services without traversing the public internet. It's designed specifically for serverless architectures using Lambda functions that need access to AWS services like DynamoDB, S3, Secrets Manager, and others.

## Features

- **Dual Mode Operation**: Can create a new VPC or use an existing one
- **Comprehensive Service Coverage**: Supports all major AWS services used by Squrl
- **Cost Optimized**: Uses Gateway endpoints where possible (free) and Interface endpoints where necessary
- **High Availability**: Multi-AZ deployment with proper subnet distribution
- **Security First**: Properly configured security groups and endpoint policies
- **Lambda Ready**: Outputs optimized for Lambda VPC configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │  Private Subnet │              │  Private Subnet │          │
│  │   10.0.1.0/24   │              │   10.0.2.0/24   │          │
│  │      AZ-a       │              │      AZ-b       │          │
│  │                 │              │                 │          │
│  │   ┌─────────┐   │              │   ┌─────────┐   │          │
│  │   │ Lambda  │   │              │   │ Lambda  │   │          │
│  │   │Functions│   │              │   │Functions│   │          │
│  │   └─────────┘   │              │   └─────────┘   │          │
│  └─────────────────┘              └─────────────────┘          │
│                                                                 │
│  VPC Endpoints:                                                 │
│  ├─ DynamoDB (Gateway)                                          │
│  ├─ S3 (Gateway)                                                │
│  ├─ Secrets Manager (Interface)                                 │
│  ├─ Parameter Store (Interface)                                 │
│  ├─ KMS (Interface)                                             │
│  ├─ Kinesis (Interface)                                         │
│  ├─ CloudWatch Logs (Interface)                                 │
│  └─ Lambda (Interface) - Optional                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Supported AWS Services

| Service | Endpoint Type | Default | Cost Impact |
|---------|---------------|---------|-------------|
| DynamoDB | Gateway | Enabled | Free |
| S3 | Gateway | Enabled | Free |
| Secrets Manager | Interface | Enabled | ~$7.2/month per AZ |
| Parameter Store | Interface | Enabled | ~$7.2/month per AZ |
| KMS | Interface | Enabled | ~$7.2/month per AZ |
| Kinesis Data Streams | Interface | Enabled | ~$7.2/month per AZ |
| CloudWatch Logs | Interface | Enabled | ~$7.2/month per AZ |
| Lambda | Interface | Disabled | ~$7.2/month per AZ |

## Usage Examples

### Basic Usage - Create New VPC

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  environment = "dev"
  
  # VPC Configuration
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"
  
  # Subnet Configuration
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # Enable core services for Squrl
  enable_dynamodb_endpoint         = true
  enable_s3_endpoint              = true
  enable_secrets_manager_endpoint = true
  enable_parameter_store_endpoint = true
  enable_kms_endpoint             = true
  enable_kinesis_endpoint         = true
  enable_logs_endpoint            = true
  
  tags = {
    Project     = "squrl"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Configure Lambda functions to use the VPC
resource "aws_lambda_function" "create_url" {
  # ... other configuration ...
  
  vpc_config {
    subnet_ids         = module.vpc_endpoints.private_subnet_ids
    security_group_ids = [module.vpc_endpoints.vpc_endpoints_security_group_id]
  }
}
```

### Advanced Usage - Use Existing VPC

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  environment = "prod"
  
  # Use existing VPC
  create_vpc = false
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-12345678", "subnet-87654321"]
  route_table_ids = ["rt-12345678", "rt-87654321"]
  
  # Selective endpoint enablement for cost optimization
  enable_dynamodb_endpoint         = true  # Free
  enable_s3_endpoint              = true  # Free
  enable_secrets_manager_endpoint = true  # $14.4/month (2 AZs)
  enable_parameter_store_endpoint = false # Use Secrets Manager instead
  enable_kms_endpoint             = true  # $14.4/month (2 AZs)
  enable_kinesis_endpoint         = true  # $14.4/month (2 AZs)
  enable_logs_endpoint            = true  # $14.4/month (2 AZs)
  enable_lambda_endpoint          = false # Not needed for Squrl
  
  # Custom security group rules
  additional_security_group_rules = [
    {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = "HTTPS from corporate network"
    }
  ]
  
  tags = {
    Project     = "squrl"
    Environment = "prod"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}
```

### Cost-Optimized Configuration

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  environment = "dev"
  create_vpc  = true
  
  # Minimal interface endpoints for development
  enable_dynamodb_endpoint         = true  # Free - Gateway
  enable_s3_endpoint              = true  # Free - Gateway
  enable_secrets_manager_endpoint = true  # Required for secrets
  enable_parameter_store_endpoint = false # Use environment variables
  enable_kms_endpoint             = false # Use default KMS
  enable_kinesis_endpoint         = true  # Required for analytics
  enable_logs_endpoint            = false # Allow internet access for logs
  enable_lambda_endpoint          = false # Not needed
  
  # Single AZ for development cost savings
  private_subnet_cidrs = ["10.0.1.0/24"]
  
  tags = {
    Project     = "squrl"
    Environment = "dev"
    CostOptimized = "true"
  }
}
```

### Production with NAT Gateway

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  environment = "prod"
  create_vpc  = true
  
  # Full VPC with NAT Gateway for hybrid connectivity
  create_nat_gateway    = true
  private_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # All endpoints enabled for production
  enable_dynamodb_endpoint         = true
  enable_s3_endpoint              = true
  enable_secrets_manager_endpoint = true
  enable_parameter_store_endpoint = true
  enable_kms_endpoint             = true
  enable_kinesis_endpoint         = true
  enable_logs_endpoint            = true
  enable_lambda_endpoint          = true
  
  # Enhanced monitoring
  enable_flow_logs              = true
  flow_logs_destination_type    = "cloud-watch-logs"
  create_vpc_endpoint_alarms    = true
  
  tags = {
    Project     = "squrl"
    Environment = "prod"
    Compliance  = "required"
    Monitoring  = "enhanced"
  }
}
```

## Integration with Squrl Lambda Functions

### Lambda VPC Configuration

```hcl
# Create URL Lambda
resource "aws_lambda_function" "create_url" {
  filename         = "create-url.zip"
  function_name    = "${var.environment}-squrl-create-url"
  role            = aws_iam_role.lambda_role.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"

  vpc_config {
    subnet_ids         = module.vpc_endpoints.private_subnet_ids
    security_group_ids = [module.vpc_endpoints.vpc_endpoints_security_group_id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.urls.name
      # VPC endpoints ensure private access to DynamoDB
    }
  }
}

# Redirect Lambda
resource "aws_lambda_function" "redirect" {
  filename         = "redirect.zip"
  function_name    = "${var.environment}-squrl-redirect"
  role            = aws_iam_role.lambda_role.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"

  vpc_config {
    subnet_ids         = module.vpc_endpoints.private_subnet_ids
    security_group_ids = [module.vpc_endpoints.vpc_endpoints_security_group_id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.urls.name
      KINESIS_STREAM_NAME = aws_kinesis_stream.analytics.name
      # VPC endpoints ensure private access to DynamoDB and Kinesis
    }
  }
}
```

## Variables Reference

### Core Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | `string` | - | Environment name (dev, staging, prod) |
| `create_vpc` | `bool` | `true` | Whether to create a new VPC |
| `vpc_id` | `string` | `""` | ID of existing VPC (if create_vpc is false) |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for new VPC |

### Subnet Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `private_subnet_cidrs` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | Private subnet CIDR blocks |
| `public_subnet_cidrs` | `list(string)` | `["10.0.101.0/24", "10.0.102.0/24"]` | Public subnet CIDR blocks |
| `subnet_ids` | `list(string)` | `[]` | Existing subnet IDs (if create_vpc is false) |
| `create_nat_gateway` | `bool` | `false` | Create NAT gateways for internet access |

### VPC Endpoint Toggles

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_dynamodb_endpoint` | `bool` | `true` | Enable DynamoDB VPC endpoint |
| `enable_s3_endpoint` | `bool` | `true` | Enable S3 VPC endpoint |
| `enable_secrets_manager_endpoint` | `bool` | `true` | Enable Secrets Manager VPC endpoint |
| `enable_parameter_store_endpoint` | `bool` | `true` | Enable Parameter Store VPC endpoint |
| `enable_kms_endpoint` | `bool` | `true` | Enable KMS VPC endpoint |
| `enable_kinesis_endpoint` | `bool` | `true` | Enable Kinesis VPC endpoint |
| `enable_lambda_endpoint` | `bool` | `false` | Enable Lambda VPC endpoint |
| `enable_logs_endpoint` | `bool` | `true` | Enable CloudWatch Logs VPC endpoint |

## Outputs Reference

### VPC Information

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR block |
| `private_subnet_ids` | Private subnet IDs |
| `public_subnet_ids` | Public subnet IDs |

### VPC Endpoints

| Output | Description |
|--------|-------------|
| `all_vpc_endpoint_ids` | All VPC endpoint IDs |
| `gateway_vpc_endpoint_ids` | Gateway VPC endpoint IDs |
| `interface_vpc_endpoint_ids` | Interface VPC endpoint IDs |
| `vpc_endpoints_security_group_id` | VPC endpoints security group ID |

### Lambda Configuration

| Output | Description |
|--------|-------------|
| `lambda_vpc_config` | VPC configuration object for Lambda functions |
| `vpc_endpoint_dns_names` | DNS names for interface endpoints |

## Security Considerations

### Network Security

1. **Security Groups**: Restrictive security group allowing only HTTPS (443) from VPC CIDR
2. **Endpoint Policies**: Each VPC endpoint has a least-privilege policy
3. **Private Subnets**: Lambda functions run in private subnets with no direct internet access
4. **DNS Resolution**: Private DNS enabled for interface endpoints

### IAM Permissions

Lambda execution roles need these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

## Cost Optimization

### Interface Endpoint Costs (per endpoint per AZ)
- **Hourly Cost**: $0.01/hour
- **Monthly Cost**: ~$7.20/month
- **Multi-AZ**: Cost multiplies by number of AZs

### Cost Optimization Strategies

1. **Use Gateway Endpoints**: DynamoDB and S3 are free
2. **Selective Enablement**: Only enable needed interface endpoints
3. **Single AZ for Dev**: Use one AZ for development environments
4. **Consolidate Services**: Use Secrets Manager instead of Parameter Store
5. **Hybrid Approach**: VPC endpoints for sensitive data, internet for logs

### Estimated Costs

| Environment | AZs | Interface Endpoints | Monthly Cost |
|-------------|-----|-------------------|--------------|
| Development | 1 | 3 (Secrets, KMS, Kinesis) | ~$21.60 |
| Staging | 2 | 4 (Secrets, KMS, Kinesis, Logs) | ~$57.60 |
| Production | 3 | 5 (Secrets, SSM, KMS, Kinesis, Logs) | ~$108.00 |

## Monitoring and Troubleshooting

### CloudWatch Metrics

Monitor these metrics for VPC endpoints:
- `PacketsDropped`
- `PacketsReceived`
- `BytesReceived`
- `ActiveConnections`

### Common Issues

1. **DNS Resolution**: Ensure private DNS is enabled
2. **Security Groups**: Check port 443 is allowed
3. **Route Tables**: Verify route table associations
4. **Subnet Selection**: Interface endpoints need multiple AZs

### Testing Connectivity

```bash
# Test DynamoDB access from Lambda
aws dynamodb list-tables --region us-east-1

# Test S3 access from Lambda
aws s3 ls --region us-east-1

# Test Secrets Manager from Lambda
aws secretsmanager get-secret-value --secret-id my-secret --region us-east-1
```

## Best Practices

1. **Multi-AZ Deployment**: Always use at least 2 AZs for production
2. **Least Privilege**: Use restrictive endpoint policies
3. **Cost Monitoring**: Monitor interface endpoint costs
4. **Security Groups**: Use specific CIDR blocks, not 0.0.0.0/0
5. **Tagging**: Consistent tagging for cost allocation
6. **Testing**: Test connectivity after deployment
7. **Documentation**: Document endpoint usage and dependencies

## Migration from Internet Access

When migrating Lambda functions from internet access to VPC endpoints:

1. **Deploy VPC endpoints** first
2. **Update Lambda VPC configuration**
3. **Test functionality** thoroughly
4. **Monitor for any issues**
5. **Remove NAT Gateway** if no longer needed

## Support

For issues with this module:
1. Check the troubleshooting section
2. Review AWS VPC endpoint documentation
3. Verify IAM permissions
4. Check security group rules
5. Test DNS resolution

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Add appropriate variable validation
3. Update documentation
4. Test with both new and existing VPC scenarios
5. Consider cost implications of changes