# Configure Terraform and Provider Requirements
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region  = var.region
  profile = var.profile
}

# Data source to get current region for outputs
data "aws_region" "current" {}

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Local values for AZ selection and subnet distribution
locals {
  # Determine how many AZs to use
  available_azs = data.aws_availability_zones.available.names
  azs_to_use    = var.max_azs == 0 ? local.available_azs : slice(local.available_azs, 0, min(var.max_azs, length(local.available_azs)))

  # Calculate AZ assignment for each subnet using round-robin
  public_subnet_azs  = [for i in range(length(var.public_subnet_cidrs)) : local.azs_to_use[i % length(local.azs_to_use)]]
  private_subnet_azs = [for i in range(length(var.private_subnet_cidrs)) : local.azs_to_use[i % length(local.azs_to_use)]]

  # Create a map of AZ usage for better visibility
  az_distribution = {
    total_azs_available  = length(local.available_azs)
    azs_being_used       = length(local.azs_to_use)
    public_subnets       = length(var.public_subnet_cidrs)
    private_subnets      = length(var.private_subnet_cidrs)
    public_distribution  = { for az in local.azs_to_use : az => length([for s_az in local.public_subnet_azs : s_az if s_az == az]) }
    private_distribution = { for az in local.azs_to_use : az => length([for s_az in local.private_subnet_azs : s_az if s_az == az]) }
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.vpc_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Public Subnets (distributed across AZs in round-robin fashion)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.public_subnet_azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-subnet-${count.index + 1}"
    Type        = "Public"
    Environment = var.environment
    Project     = var.project_name
    AZ          = local.public_subnet_azs[count.index]
    AZIndex     = "${index(local.azs_to_use, local.public_subnet_azs[count.index]) + 1} of ${length(local.azs_to_use)}"
  }
}

# Create Private Subnets (distributed across AZs in round-robin fashion)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.private_subnet_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.vpc_name}-private-subnet-${count.index + 1}"
    Type        = "Private"
    Environment = var.environment
    Project     = var.project_name
    AZ          = local.private_subnet_azs[count.index]
    AZIndex     = "${index(local.azs_to_use, local.private_subnet_azs[count.index]) + 1} of ${length(local.azs_to_use)}"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-public-rt"
    Type        = "Public"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-private-rt"
    Type        = "Private"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create public route (0.0.0.0/0 -> Internet Gateway)
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Application Security Group
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for EC2 instances hosting web applications"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port
  ingress {
    description = "Application port from anywhere"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.vpc_name}-application-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EC2 Instance
resource "aws_instance" "application" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.application.id]
  associate_public_ip_address = true

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  # Disable termination protection
  disable_api_termination = false

  # Ensure network is ready before launching
  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public
  ]

  tags = {
    Name        = "${var.vpc_name}-application"
    Environment = var.environment
    Project     = var.project_name
    Role        = "web-app"
  }
}