# ==============================================================================
# Secret for RDS Database Password
# ==============================================================================
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.vpc_name}-db-password"
  description             = "RDS database credentials"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.vpc_name}-db-password"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "RDS Credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })

  depends_on = [
    aws_db_instance.main
  ]
}

# ==============================================================================
# Secret for Email Service Credentials
# ==============================================================================
resource "aws_secretsmanager_secret" "email_credentials" {
  name                    = "${var.vpc_name}-email-credentials"
  description             = "Email service credentials (SendGrid)"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.vpc_name}-email-credentials"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Email Service Credentials"
  }
}

resource "aws_secretsmanager_secret_version" "email_credentials" {
  secret_id = aws_secretsmanager_secret.email_credentials.id

  secret_string = jsonencode({
    api_key    = var.email_api_key
    from_email = var.email_from_address
  })
}