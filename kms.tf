data "aws_caller_identity" "current" {}
# ==============================================================================
# KMS Key for EC2 EBS Volumes
# ==============================================================================
resource "aws_kms_key" "ec2" {
  description             = "KMS key for EC2 EBS volume encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  tags = {
    Name        = "${var.vpc_name}-ec2-kms"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "EC2 EBS Encryption"
  }
}

resource "aws_kms_alias" "ec2" {
  name          = "alias/${var.vpc_name}-ec2"
  target_key_id = aws_kms_key.ec2.key_id
}

# ==============================================================================
# KMS Key for RDS
# ==============================================================================
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  tags = {
    Name        = "${var.vpc_name}-rds-kms"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "RDS Encryption"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.vpc_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ==============================================================================
# KMS Key for S3
# ==============================================================================
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  tags = {
    Name        = "${var.vpc_name}-s3-kms"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "S3 Encryption"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.vpc_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ==============================================================================
# KMS Key for Secrets Manager
# ==============================================================================
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-policy-secrets"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"  # ← DYNAMIC
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 Role to Decrypt Secrets"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_instance_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-secrets-kms"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Secrets Manager Encryption"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.vpc_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}