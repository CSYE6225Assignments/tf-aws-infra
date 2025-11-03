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

# Local values for AZ selection and auto-generated subnets
locals {
  # AZ selection
  available_azs = data.aws_availability_zones.available.names
  azs_to_use    = var.max_azs == 0 ? local.available_azs : slice(local.available_azs, 0, min(var.max_azs, length(local.available_azs)))
  az_count      = length(local.azs_to_use)

  # We’ll make one public and one private subnet per AZ
  public_subnet_count  = local.az_count
  private_subnet_count = local.az_count

  # Auto-generate /24 subnets from the VPC CIDR (assumes VPC like /16; adjust “8” if your VPC mask differs)
  # First N /24s for public, next N /24s for private
  public_subnet_cidrs_auto  = [for i in range(local.public_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs_auto = [for i in range(local.private_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + local.public_subnet_count)]

  # Round-robin AZ assignment based on counts above
  public_subnet_azs  = [for i in range(local.public_subnet_count) : local.azs_to_use[i % local.az_count]]
  private_subnet_azs = [for i in range(local.private_subnet_count) : local.azs_to_use[i % local.az_count]]

  # Distribution info (for outputs/debug)
  az_distribution = {
    total_azs_available  = length(local.available_azs)
    azs_being_used       = local.az_count
    public_subnets       = local.public_subnet_count
    private_subnets      = local.private_subnet_count
    public_distribution  = { for az in local.azs_to_use : az => length([for az2 in local.public_subnet_azs : az2 if az2 == az]) }
    private_distribution = { for az in local.azs_to_use : az => length([for az2 in local.private_subnet_azs : az2 if az2 == az]) }
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
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs_auto[count.index]
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
  count                   = local.private_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs_auto[count.index]
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

# # EC2 Instance
# resource "aws_instance" "application" {
#   ami                         = var.ami_id
#   instance_type               = var.instance_type
#   key_name                    = var.key_name
#   subnet_id                   = aws_subnet.public[0].id
#   vpc_security_group_ids      = [aws_security_group.application.id]
#   associate_public_ip_address = true
#
#   # Attach IAM Instance Profile for S3 and CloudWatch access
#   iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
#
#   # User data script with RDS, S3, and CloudWatch configuration
#   user_data = templatefile("${path.module}/user-data.sh", {
#     environment    = var.environment
#     db_hostname    = aws_db_instance.main.address
#     db_port        = aws_db_instance.main.port
#     db_name        = aws_db_instance.main.db_name
#     db_username    = var.db_username
#     db_password    = random_password.db_password.result
#     s3_bucket_name = aws_s3_bucket.images.bucket
#     aws_region     = var.region
#   })
#
#   # Root volume configuration
#   root_block_device {
#     volume_size           = var.root_volume_size
#     volume_type           = var.root_volume_type
#     delete_on_termination = true
#   }
#
#   disable_api_termination = false
#
#   # Wait for all dependencies
#   depends_on = [
#     aws_internet_gateway.main,
#     aws_route_table_association.public,
#     aws_db_instance.main,
#     aws_s3_bucket.images,
#     aws_iam_instance_profile.ec2_instance_profile,
#     aws_cloudwatch_log_group.application
#   ]
#
#   tags = {
#     Name        = "${var.vpc_name}-application"
#     Environment = var.environment
#     Project     = var.project_name
#     Role        = "web-app"
#   }
# }