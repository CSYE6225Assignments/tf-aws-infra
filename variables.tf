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

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# Security Configuration
variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into EC2 instances (restrict to your IP for security)"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block (e.g., 203.0.113.0/32 for single IP)."
  }
}

# Auto Scaling Group Configuration
variable "asg_min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.asg_min_size >= 1 && var.asg_min_size <= 10
    error_message = "ASG min size must be between 1 and 10."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 5

  validation {
    condition     = var.asg_max_size >= 1 && var.asg_max_size <= 10
    error_message = "ASG max size must be between 1 and 10."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.asg_desired_capacity >= 1
    error_message = "ASG desired capacity must be at least 1."
  }
}

variable "asg_health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = 300
}

variable "asg_default_cooldown" {
  description = "Amount of time (in seconds) after a scaling activity completes before another can begin"
  type        = number
  default     = 60
}