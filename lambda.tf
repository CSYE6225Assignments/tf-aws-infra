# ==============================================================================
# Lambda Function for Email Verification
# ==============================================================================
resource "aws_lambda_function" "email_verification" {
  filename         = "${path.module}/lambda-placeholder.zip"
  function_name    = "${var.vpc_name}-email-verification"
  role             = aws_iam_role.lambda_email_verification.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambda-placeholder.zip")
  runtime          = "nodejs18.x"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      EMAIL_TRACKING_TABLE = aws_dynamodb_table.email_tracking.name
      SENDGRID_API_KEY     = var.sendgrid_api_key
      FROM_EMAIL           = var.email_from_address
    }
  }

  tags = {
    Name        = "${var.vpc_name}-email-verification"
    Environment = var.environment
    Project     = var.project_name
  }

  # Ignore code changes - GitHub Actions will update the function
  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_attachment,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# ==============================================================================
# CloudWatch Log Group for Lambda
# ==============================================================================
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.vpc_name}-email-verification"
  retention_in_days = 7

  tags = {
    Name        = "${var.vpc_name}-lambda-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================================
# SNS Topic Subscription - Lambda
# ==============================================================================
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.user_verification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_verification.arn

  depends_on = [aws_lambda_function.email_verification]
}

# ==============================================================================
# Lambda Permission - Allow SNS to Invoke
# ==============================================================================
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_verification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification.arn

  depends_on = [aws_lambda_function.email_verification]
}