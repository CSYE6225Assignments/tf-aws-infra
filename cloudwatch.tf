# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/csye6225/${var.environment}/application"
  retention_in_days = 7

  tags = {
    Name        = "${var.vpc_name}-application-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}