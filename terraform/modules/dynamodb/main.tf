resource "aws_dynamodb_table" "urls" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  
  hash_key = "short_code"
  
  attribute {
    name = "short_code"
    type = "S"
  }
  
  attribute {
    name = "original_url"
    type = "S"
  }
  
  global_secondary_index {
    name            = "original_url_index"
    hash_key        = "original_url"
    projection_type = "ALL"
  }
  
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Environment = var.environment
    Service     = "squrl"
    ManagedBy   = "terraform"
  }
}