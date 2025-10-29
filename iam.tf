# IAM Role for EC2 Instance
resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.vpc_name}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-ec2-instance-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.vpc_name}-s3-access-policy"
  description = "Policy to allow EC2 to access S3 bucket for images"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.images.arn,
          "${aws_s3_bucket.images.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-s3-access-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach S3 Policy to EC2 Role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.vpc_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name

  tags = {
    Name        = "${var.vpc_name}-ec2-instance-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for CloudWatch Logs and Metrics
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${var.vpc_name}-cloudwatch-policy"
  description = "Policy to allow EC2 to send logs and metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CSYE6225"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })

  tags = {
    Name        = "${var.vpc_name}-cloudwatch-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach CloudWatch Policy to EC2 Role
resource "aws_iam_role_policy_attachment" "cloudwatch_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}