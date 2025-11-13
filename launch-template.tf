# LAUNCH TEMPLATE FOR AUTO SCALING GROUP

resource "aws_launch_template" "application" {
  name_prefix   = "${var.vpc_name}-lt-"
  description   = "Launch template for ${var.vpc_name} application instances"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # IAM Instance Profile for S3 and CloudWatch access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  # Network Configuration
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application.id]
    delete_on_termination       = true
  }

  # User Data Script (with Secrets Manager)
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    environment     = var.environment
    db_secret_id    = aws_secretsmanager_secret.db_password.id
    email_secret_id = aws_secretsmanager_secret.email_credentials.id
    s3_bucket_name  = aws_s3_bucket.images.bucket
    aws_region      = var.region
  }))

  # Root Volume Configuration
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
      #kms_key_id            = aws_kms_key.ec2.arn
    }
  }

  # Instance Metadata Service Configuration (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Tags for instances launched from this template
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.vpc_name}-asg-instance"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "AutoScaling"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.vpc_name}-asg-volume"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_iam_instance_profile.ec2_instance_profile,
    aws_security_group.application,
    aws_db_instance.main,
    aws_s3_bucket.images,
    aws_secretsmanager_secret_version.db_password,
    aws_secretsmanager_secret_version.email_credentials
  ]

  tags = {
    Name        = "${var.vpc_name}-launch-template"
    Environment = var.environment
    Project     = var.project_name
  }

  # Create a new version when template changes
  lifecycle {
    create_before_destroy = true
  }
}