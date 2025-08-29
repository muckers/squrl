# VPC Endpoints Module Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].id : var.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].cidr_block : data.aws_vpc.existing[0].cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].arn : data.aws_vpc.existing[0].arn
}

# Subnet Outputs
output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].id : var.subnet_ids
}

output "private_subnet_arns" {
  description = "ARNs of the private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].arn : []
}

output "private_subnet_cidr_blocks" {
  description = "CIDR blocks of the private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].cidr_block : []
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = var.create_vpc && var.create_nat_gateway ? aws_subnet.public[*].id : []
}

output "public_subnet_arns" {
  description = "ARNs of the public subnets"
  value       = var.create_vpc && var.create_nat_gateway ? aws_subnet.public[*].arn : []
}

output "public_subnet_cidr_blocks" {
  description = "CIDR blocks of the public subnets"
  value       = var.create_vpc && var.create_nat_gateway ? aws_subnet.public[*].cidr_block : []
}

# Internet Gateway Outputs
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.create_vpc ? try(aws_internet_gateway.main[0].id, null) : null
}

output "internet_gateway_arn" {
  description = "ARN of the Internet Gateway"
  value       = var.create_vpc ? try(aws_internet_gateway.main[0].arn, null) : null
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = var.create_vpc && var.create_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = var.create_vpc && var.create_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# Route Table Outputs
output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = var.create_vpc ? aws_route_table.private[*].id : var.route_table_ids
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = var.create_vpc ? try(aws_route_table.public[0].id, null) : null
}

# Security Group Outputs
output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpc_endpoints_security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.arn
}

# VPC Endpoint Outputs
output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB VPC endpoint"
  value       = var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : null
}

output "dynamodb_vpc_endpoint_arn" {
  description = "ARN of the DynamoDB VPC endpoint"
  value       = var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].arn : null
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "s3_vpc_endpoint_arn" {
  description = "ARN of the S3 VPC endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].arn : null
}

output "secrets_manager_vpc_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint"
  value       = var.enable_secrets_manager_endpoint ? aws_vpc_endpoint.secrets_manager[0].id : null
}

output "secrets_manager_vpc_endpoint_arn" {
  description = "ARN of the Secrets Manager VPC endpoint"
  value       = var.enable_secrets_manager_endpoint ? aws_vpc_endpoint.secrets_manager[0].arn : null
}

output "secrets_manager_vpc_endpoint_dns_entry" {
  description = "DNS entries of the Secrets Manager VPC endpoint"
  value       = var.enable_secrets_manager_endpoint ? aws_vpc_endpoint.secrets_manager[0].dns_entry : []
}

output "parameter_store_vpc_endpoint_id" {
  description = "ID of the Parameter Store VPC endpoint"
  value       = var.enable_parameter_store_endpoint ? aws_vpc_endpoint.ssm[0].id : null
}

output "parameter_store_vpc_endpoint_arn" {
  description = "ARN of the Parameter Store VPC endpoint"
  value       = var.enable_parameter_store_endpoint ? aws_vpc_endpoint.ssm[0].arn : null
}

output "parameter_store_vpc_endpoint_dns_entry" {
  description = "DNS entries of the Parameter Store VPC endpoint"
  value       = var.enable_parameter_store_endpoint ? aws_vpc_endpoint.ssm[0].dns_entry : []
}

output "kms_vpc_endpoint_id" {
  description = "ID of the KMS VPC endpoint"
  value       = var.enable_kms_endpoint ? aws_vpc_endpoint.kms[0].id : null
}

output "kms_vpc_endpoint_arn" {
  description = "ARN of the KMS VPC endpoint"
  value       = var.enable_kms_endpoint ? aws_vpc_endpoint.kms[0].arn : null
}

output "kms_vpc_endpoint_dns_entry" {
  description = "DNS entries of the KMS VPC endpoint"
  value       = var.enable_kms_endpoint ? aws_vpc_endpoint.kms[0].dns_entry : []
}

output "kinesis_vpc_endpoint_id" {
  description = "ID of the Kinesis VPC endpoint"
  value       = var.enable_kinesis_endpoint ? aws_vpc_endpoint.kinesis_streams[0].id : null
}

output "kinesis_vpc_endpoint_arn" {
  description = "ARN of the Kinesis VPC endpoint"
  value       = var.enable_kinesis_endpoint ? aws_vpc_endpoint.kinesis_streams[0].arn : null
}

output "kinesis_vpc_endpoint_dns_entry" {
  description = "DNS entries of the Kinesis VPC endpoint"
  value       = var.enable_kinesis_endpoint ? aws_vpc_endpoint.kinesis_streams[0].dns_entry : []
}

output "lambda_vpc_endpoint_id" {
  description = "ID of the Lambda VPC endpoint"
  value       = var.enable_lambda_endpoint ? aws_vpc_endpoint.lambda[0].id : null
}

output "lambda_vpc_endpoint_arn" {
  description = "ARN of the Lambda VPC endpoint"
  value       = var.enable_lambda_endpoint ? aws_vpc_endpoint.lambda[0].arn : null
}

output "lambda_vpc_endpoint_dns_entry" {
  description = "DNS entries of the Lambda VPC endpoint"
  value       = var.enable_lambda_endpoint ? aws_vpc_endpoint.lambda[0].dns_entry : []
}

output "logs_vpc_endpoint_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = var.enable_logs_endpoint ? aws_vpc_endpoint.logs[0].id : null
}

output "logs_vpc_endpoint_arn" {
  description = "ARN of the CloudWatch Logs VPC endpoint"
  value       = var.enable_logs_endpoint ? aws_vpc_endpoint.logs[0].arn : null
}

output "logs_vpc_endpoint_dns_entry" {
  description = "DNS entries of the CloudWatch Logs VPC endpoint"
  value       = var.enable_logs_endpoint ? aws_vpc_endpoint.logs[0].dns_entry : []
}

# Aggregated Outputs
output "all_vpc_endpoint_ids" {
  description = "List of all VPC endpoint IDs"
  value = compact([
    var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : "",
    var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : "",
    var.enable_secrets_manager_endpoint ? aws_vpc_endpoint.secrets_manager[0].id : "",
    var.enable_parameter_store_endpoint ? aws_vpc_endpoint.ssm[0].id : "",
    var.enable_kms_endpoint ? aws_vpc_endpoint.kms[0].id : "",
    var.enable_kinesis_endpoint ? aws_vpc_endpoint.kinesis_streams[0].id : "",
    var.enable_lambda_endpoint ? aws_vpc_endpoint.lambda[0].id : "",
    var.enable_logs_endpoint ? aws_vpc_endpoint.logs[0].id : ""
  ])
}

output "gateway_vpc_endpoint_ids" {
  description = "List of Gateway VPC endpoint IDs"
  value = compact([
    var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : "",
    var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : ""
  ])
}

output "interface_vpc_endpoint_ids" {
  description = "List of Interface VPC endpoint IDs"
  value = compact([
    var.enable_secrets_manager_endpoint ? aws_vpc_endpoint.secrets_manager[0].id : "",
    var.enable_parameter_store_endpoint ? aws_vpc_endpoint.ssm[0].id : "",
    var.enable_kms_endpoint ? aws_vpc_endpoint.kms[0].id : "",
    var.enable_kinesis_endpoint ? aws_vpc_endpoint.kinesis_streams[0].id : "",
    var.enable_lambda_endpoint ? aws_vpc_endpoint.lambda[0].id : "",
    var.enable_logs_endpoint ? aws_vpc_endpoint.logs[0].id : ""
  ])
}

# Lambda Configuration Outputs
output "lambda_vpc_config" {
  description = "VPC configuration for Lambda functions"
  value = {
    subnet_ids         = var.create_vpc ? aws_subnet.private[*].id : var.subnet_ids
    security_group_ids = [aws_security_group.vpc_endpoints.id]
  }
}

# DNS Configuration Outputs
output "vpc_endpoint_dns_names" {
  description = "DNS names for interface VPC endpoints"
  value = {
    secrets_manager = var.enable_secrets_manager_endpoint && length(aws_vpc_endpoint.secrets_manager[0].dns_entry) > 0 ? aws_vpc_endpoint.secrets_manager[0].dns_entry[0].dns_name : ""
    parameter_store = var.enable_parameter_store_endpoint && length(aws_vpc_endpoint.ssm[0].dns_entry) > 0 ? aws_vpc_endpoint.ssm[0].dns_entry[0].dns_name : ""
    kms             = var.enable_kms_endpoint && length(aws_vpc_endpoint.kms[0].dns_entry) > 0 ? aws_vpc_endpoint.kms[0].dns_entry[0].dns_name : ""
    kinesis         = var.enable_kinesis_endpoint && length(aws_vpc_endpoint.kinesis_streams[0].dns_entry) > 0 ? aws_vpc_endpoint.kinesis_streams[0].dns_entry[0].dns_name : ""
    lambda          = var.enable_lambda_endpoint && length(aws_vpc_endpoint.lambda[0].dns_entry) > 0 ? aws_vpc_endpoint.lambda[0].dns_entry[0].dns_name : ""
    logs            = var.enable_logs_endpoint && length(aws_vpc_endpoint.logs[0].dns_entry) > 0 ? aws_vpc_endpoint.logs[0].dns_entry[0].dns_name : ""
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for VPC endpoints (interface endpoints only)"
  value = {
    interface_endpoints_count = length(compact([
      var.enable_secrets_manager_endpoint ? "secrets_manager" : "",
      var.enable_parameter_store_endpoint ? "parameter_store" : "",
      var.enable_kms_endpoint ? "kms" : "",
      var.enable_kinesis_endpoint ? "kinesis" : "",
      var.enable_lambda_endpoint ? "lambda" : "",
      var.enable_logs_endpoint ? "logs" : ""
    ]))
    estimated_cost_usd = length(compact([
      var.enable_secrets_manager_endpoint ? "secrets_manager" : "",
      var.enable_parameter_store_endpoint ? "parameter_store" : "",
      var.enable_kms_endpoint ? "kms" : "",
      var.enable_kinesis_endpoint ? "kinesis" : "",
      var.enable_lambda_endpoint ? "lambda" : "",
      var.enable_logs_endpoint ? "logs" : ""
    ])) * 7.2 * length(var.create_vpc ? aws_subnet.private : var.subnet_ids)
    note = "Estimate based on $0.01/hour per interface endpoint per AZ. Gateway endpoints (S3, DynamoDB) are free."
  }
}

# Availability Zones
output "availability_zones" {
  description = "Availability zones used by the subnets"
  value       = var.create_vpc ? aws_subnet.private[*].availability_zone : []
}

# Region
output "aws_region" {
  description = "AWS region where resources are created"
  value       = data.aws_region.current.id
}