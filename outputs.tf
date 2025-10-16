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

# EC2 Instance Outputs
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.application.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP address"
  value       = aws_instance.application.public_ip
}

output "instance_public_dns" {
  description = "EC2 instance public DNS name"
  value       = aws_instance.application.public_dns
}

output "instance_private_ip" {
  description = "EC2 instance private IP address"
  value       = aws_instance.application.private_ip
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_instance.application.public_ip}:${var.app_port}"
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "http://${aws_instance.application.public_ip}:${var.app_port}/healthz"
}