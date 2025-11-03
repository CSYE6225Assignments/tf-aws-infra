# AUTO SCALING GROUP
resource "aws_autoscaling_group" "application" {
  name                      = "${var.vpc_name}-asg"
  vpc_zone_identifier       = aws_subnet.public[*].id
  target_group_arns         = [aws_lb_target_group.application.arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.asg_health_check_grace_period

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  default_cooldown          = var.asg_default_cooldown
  force_delete              = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.application.id
    version = "$Latest"
  }

  # Instance tags (propagated to instances)
  tag {
    key                 = "Name"
    value               = "${var.vpc_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }

  # Ensure dependencies are ready
  depends_on = [
    aws_lb.application,
    aws_lb_target_group.application,
    aws_launch_template.application
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}