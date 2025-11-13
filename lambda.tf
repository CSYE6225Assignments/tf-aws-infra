# ==============================================================================
# Lambda IAM Role
# ==============================================================================
resource "aws_iam_role" "lambda_role" {
  name = "${var.vpc_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-lambda-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================================
# Lambda Policy for CloudWatch Logs
# ==============================================================================
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ==============================================================================
# Lambda Policy for DynamoDB Access
# ==============================================================================
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.vpc_name}-lambda-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB email tracking table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.email_tracking.arn
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-lambda-dynamodb-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# ==============================================================================
# Lambda Function
# ==============================================================================
resource "aws_lambda_function" "email_verification" {
  function_name = "${var.vpc_name}-email-verification"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30
  memory_size   = 256

  # Placeholder code (will be replaced by CI/CD)
  filename         = "${path.module}/lambda_placeholder.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_placeholder.zip")

  environment {
    variables = {
      EMAIL_TRACKING_TABLE = aws_dynamodb_table.email_tracking.name
      FROM_EMAIL           = var.email_from_address
      SENDGRID_API_KEY     = var.email_api_key
    }
  }

  tags = {
    Name        = "${var.vpc_name}-email-verification"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_dynamodb
  ]
}

# ==============================================================================
# SNS Subscription for Lambda
# ==============================================================================
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.user_verification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_verification.arn
}

# ==============================================================================
# Lambda Permission for SNS
# ==============================================================================
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_verification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification.arn
}