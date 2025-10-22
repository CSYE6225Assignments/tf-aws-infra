variable "region" {
  description = "AWS region for resources"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for VPC and its resources (must be unique for each deployment)"
  type        = string

  validation {
    condition     = length(var.vpc_name) > 0
    error_message = "VPC name cannot be empty."
  }
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "csye6225"
}

variable "environment" {
  description = "Environment name (dev, demo, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "demo", "prod"], var.environment)
    error_message = "Environment must be dev, demo, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "At least one public subnet CIDR is required."
  }

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least one private subnet CIDR is required."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "max_azs" {
  description = "Maximum number of AZs to use (0 = use all available)"
  type        = number
  default     = 0

  validation {
    condition     = var.max_azs >= 0
    error_message = "max_azs must be 0 or positive."
  }
}

# EC2 Instance Variables
variable "ami_id" {
  description = "Custom AMI ID built by Packer"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Instance type must be t2.micro, t2.small, t3.micro, or t3.small."
  }
}

variable "key_name" {
  description = "EC2 key pair name for SSH access (optional)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 25
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["gp2", "gp3"], var.root_volume_type)
    error_message = "Root volume type must be gp2 or gp3."
  }
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}

# RDS Configuration Variables
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition     = contains(["db.t3.micro", "db.t4g.micro", "db.t2.micro"], var.db_instance_class)
    error_message = "DB instance class must be db.t3.micro, db.t4g.micro, or db.t2.micro."
  }
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 100
    error_message = "Allocated storage must be between 20 and 100 GB."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "csye6225"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "csye6225"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters."
  }
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}