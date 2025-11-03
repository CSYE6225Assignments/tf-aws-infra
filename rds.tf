# Generate random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters not allowed by RDS: /, @, ", and space
  override_special = "!#$%&*()-_=+[]{}|:;<>,.?"
}

# RDS Subnet Group - Use private subnets only
resource "aws_db_subnet_group" "main" {
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.vpc_name}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Custom RDS Parameter Group (NOT default)
resource "aws_db_parameter_group" "main" {
  name   = "${var.vpc_name}-mysql-params"
  family = "mysql8.0"

  description = "Custom parameter group for MySQL 8.0"

  # Example parameters - you can add more as needed
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = {
    Name        = "${var.vpc_name}-mysql-params"
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Instance - MySQL
resource "aws_db_instance" "main" {
  identifier = "csye6225"

  # Engine Configuration
  engine            = "mysql"
  engine_version    = "8.0.40"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  # Custom Parameter Group (NOT default)
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup Configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # High Availability
  multi_az = var.db_multi_az

  # Deletion Protection
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = null

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name        = "csye6225"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_db_parameter_group.main,
    aws_db_subnet_group.main
  ]
}