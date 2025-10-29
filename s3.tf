# Generate UUID to ensure global uniqueness
resource "random_uuid" "images" {}

# Build a friendly, unique bucket name (all lowercase)
locals {
  s3_bucket_name = "csye6225-images-${random_uuid.images.result}"
}

# Private S3 bucket for user images
resource "aws_s3_bucket" "images" {
  bucket        = local.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = local.s3_bucket_name
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "User image storage"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (recommended)
resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: STANDARD -> STANDARD_IA after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "transition-to-standard-ia-30-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}