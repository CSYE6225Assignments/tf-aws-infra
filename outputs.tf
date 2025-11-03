output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = var.vpc_name
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones_info" {
  description = "Detailed AZ distribution information"
  value = {
    region              = var.region
    available_azs       = local.available_azs
    azs_in_use          = local.azs_to_use
    total_azs_available = length(local.available_azs)
    total_azs_used      = length(local.azs_to_use)
  }
}

output "subnet_distribution" {
  description = "How subnets are distributed across AZs"
  value       = local.az_distribution
}

output "public_subnets" {
  description = "Details of public subnets"
  value = [for i, subnet in aws_subnet.public : {
    id                = subnet.id
    cidr_block        = subnet.cidr_block
    availability_zone = subnet.availability_zone
    name              = subnet.tags["Name"]
  }]
}

output "private_subnets" {
  description = "Details of private subnets"
  value = [for i, subnet in aws_subnet.private : {
    id                = subnet.id
    cidr_block        = subnet.cidr_block
    availability_zone = subnet.availability_zone
    name              = subnet.tags["Name"]
  }]
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Application Security Group Outputs
output "application_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

output "application_security_group_name" {
  description = "Name of the application security group"
  value       = aws_security_group.application.name
}

# S3 Bucket Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for images"
  value       = aws_s3_bucket.images.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.images.arn
}

output "s3_bucket_region" {
  description = "Region where the S3 bucket is created"
  value       = data.aws_region.current.name
}

# Database Security Group Outputs
output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "database_security_group_name" {
  description = "Name of the database security group"
  value       = aws_security_group.database.name
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = var.db_username
  sensitive   = true
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.main.name
}

# IAM Outputs
output "iam_role_name" {
  description = "Name of the IAM role for EC2"
  value       = aws_iam_role.ec2_instance_role.name
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.arn
}

# LOAD BALANCER SECURITY GROUP OUTPUTS
output "load_balancer_security_group_id" {
  description = "ID of the load balancer security group"
  value       = aws_security_group.load_balancer.id
}

output "load_balancer_security_group_name" {
  description = "Name of the load balancer security group"
  value       = aws_security_group.load_balancer.name
}

# LAUNCH TEMPLATE OUTPUTS
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.application.id
}

output "launch_template_name" {
  description = "Name of the launch template"
  value       = aws_launch_template.application.name
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.application.latest_version
}

output "launch_template_default_version" {
  description = "Default version of the launch template"
  value       = aws_launch_template.application.default_version
}

# LOAD BALANCER OUTPUTS
output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.application.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.application.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.application.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.application.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.application.arn
}

output "target_group_name" {
  description = "Name of the Target Group"
  value       = aws_lb_target_group.application.name
}

output "alb_url" {
  description = "URL to access the application via Load Balancer"
  value       = "http://${aws_lb.application.dns_name}"
}

output "alb_healthcheck_url" {
  description = "Health check URL via Load Balancer"
  value       = "http://${aws_lb.application.dns_name}/healthz"
}

# AUTO SCALING GROUP OUTPUTS
output "asg_id" {
  description = "Auto Scaling Group ID"
  value       = aws_autoscaling_group.application.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.application.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.application.arn
}

output "asg_min_size" {
  description = "ASG minimum size"
  value       = aws_autoscaling_group.application.min_size
}

output "asg_max_size" {
  description = "ASG maximum size"
  value       = aws_autoscaling_group.application.max_size
}

output "asg_desired_capacity" {
  description = "ASG desired capacity"
  value       = aws_autoscaling_group.application.desired_capacity
}

# AUTO SCALING POLICY OUTPUTS
output "scale_up_policy_name" {
  description = "Name of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.name
}

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_name" {
  description = "Name of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.name
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.arn
}

output "cpu_high_alarm_name" {
  description = "Name of the CPU high alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "cpu_low_alarm_name" {
  description = "Name of the CPU low alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_low.alarm_name
}