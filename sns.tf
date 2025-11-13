# ==============================================================================
# SNS Topic for User Verification
# ==============================================================================
resource "aws_sns_topic" "user_verification" {
  name              = "${var.vpc_name}-user-verification"
  display_name      = "User Email Verification"
  kms_master_key_id = aws_kms_key.secrets.arn

  tags = {
    Name        = "${var.vpc_name}-user-verification"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "User Email Verification"
  }
}