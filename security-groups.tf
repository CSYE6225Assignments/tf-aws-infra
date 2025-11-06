# ==============================================================================
# LOAD BALANCER SECURITY GROUP (NEW)
# ==============================================================================
resource "aws_security_group" "load_balancer" {
  name        = "${var.vpc_name}-lb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere (port 80)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere (port 443) - for future use
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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
    Name        = "${var.vpc_name}-lb-sg"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Load Balancer"
  }
}

# ==============================================================================
# APPLICATION SECURITY GROUP (UPDATED)
# ==============================================================================
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for EC2 instances hosting web applications"
  vpc_id      = aws_vpc.main.id

  # SSH access (restricted to specific CIDR)
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # REMOVED: Direct HTTP access from anywhere
  # REMOVED: Direct HTTPS access from anywhere
  # REMOVED: Direct app port access from anywhere

  # Application port access is now defined as a separate rule below
  # that only allows traffic from the load balancer

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
    Purpose     = "Application Server"
  }
}

# ==============================================================================
# APPLICATION SECURITY GROUP RULE - Traffic from Load Balancer ONLY
# ==============================================================================
resource "aws_security_group_rule" "app_from_lb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.application.id
  source_security_group_id = aws_security_group.load_balancer.id
  description              = "Application traffic from Load Balancer only"

  # Ensure security groups are created first
  depends_on = [
    aws_security_group.application,
    aws_security_group.load_balancer
  ]
}

# ==============================================================================
# DATABASE SECURITY GROUP (NO CHANGES)
# ==============================================================================
resource "aws_security_group" "database" {
  name        = "${var.vpc_name}-database-sg"
  description = "Security group for RDS database instances"
  vpc_id      = aws_vpc.main.id

  # No inline ingress - using separate rule resource below

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.vpc_name}-database-sg"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "RDS Database"
  }
}

# Database ingress rule: Allow MySQL/MariaDB ONLY from application security group
resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.database.id
  source_security_group_id = aws_security_group.application.id
  description              = "MySQL/MariaDB from application servers only"
}