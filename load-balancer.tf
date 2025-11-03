# ==============================================================================
# APPLICATION LOAD BALANCER TARGET GROUP
# ==============================================================================
resource "aws_lb_target_group" "application" {
  name     = "${var.vpc_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health Check Configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
  }

  # Deregistration delay (time to drain connections)
  deregistration_delay = 30

  # Target type
  target_type = "instance"

  # Stickiness (optional - disabled for now)
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name        = "${var.vpc_name}-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================================
# APPLICATION LOAD BALANCER
# ==============================================================================
resource "aws_lb" "application" {
  name               = "${var.vpc_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id

  # Enable deletion protection (set to false for dev)
  enable_deletion_protection = false

  # Enable access logs (disabled for now)
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   enabled = true
  # }

  # Enable cross-zone load balancing
  enable_cross_zone_load_balancing = true

  # Enable HTTP/2
  enable_http2 = true

  # Idle timeout
  idle_timeout = 60

  tags = {
    Name        = "${var.vpc_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# LOAD BALANCER LISTENER (HTTP:80)
# ==============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }

  tags = {
    Name        = "${var.vpc_name}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================================
# TEMPORARILY REGISTER STANDALONE EC2 INSTANCE
# ==============================================================================
# This allows us to test the Load Balancer before ASG is created

# resource "aws_lb_target_group_attachment" "standalone_instance" {
#   target_group_arn = aws_lb_target_group.application.arn
#   target_id        = aws_instance.application.id
#   port             = var.app_port
#
#   # Lifecycle to prevent errors during when we remove standalone EC2
#   lifecycle {
#     create_before_destroy = true
#   }
# }