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

# SCALE UP POLICY
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.vpc_name}-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.application.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_up_adjustment
  cooldown               = var.scaling_policy_cooldown
  policy_type            = "SimpleScaling"
}

# SCALE UP CLOUDWATCH ALARM (IMPROVED)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.vpc_name}-cpu-high"
  alarm_description   = "Triggers scale up when average CPU exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_up_cpu_threshold
  unit                = "Percent"

  # Avoid false alarms during instance warm-up
  treat_missing_data  = "notBreaching"
  datapoints_to_alarm = 2

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.application.name
  }

  tags = {
    Name        = "${var.vpc_name}-cpu-high-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SCALE DOWN POLICY
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.vpc_name}-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.application.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_down_adjustment
  cooldown               = var.scaling_policy_cooldown
  policy_type            = "SimpleScaling"
}

# SCALE DOWN CLOUDWATCH ALARM
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.vpc_name}-cpu-low"
  alarm_description   = "Triggers scale down when average CPU falls below threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_down_cpu_threshold
  unit                = "Percent"

  # Prevent accidental scale-down on data gaps
  treat_missing_data  = "missing"
  datapoints_to_alarm = 2

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.application.name
  }

  tags = {
    Name        = "${var.vpc_name}-cpu-low-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}