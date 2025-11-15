# ==============================================================================
# DynamoDB Table for Email Tracking (Prevent Duplicates)
# ==============================================================================
resource "aws_dynamodb_table" "email_tracking" {
  name         = "${var.vpc_name}-EmailTracking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"
  range_key    = "token"

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "token"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.vpc_name}-email-tracking"
    Environment = var.environment
    Project     = var.project_name
  }
}