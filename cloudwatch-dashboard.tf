# cloudwatch-dashboard.tf

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # EC2 Auto Scaling Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.application.name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupMinSize", ".", "."],
            [".", "GroupMaxSize", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Auto Scaling Group Status"
        }
      },

      # Application Load Balancer Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.application.arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Load Balancer Metrics"
        }
      },

      # Target Health
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.application.arn_suffix, "LoadBalancer", aws_lb.application.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Target Health"
        }
      },

      # RDS Database Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Database Metrics"
        }
      },

      # Lambda Function Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.email_verification.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Email Verification"
        }
      },

      # DynamoDB Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.email_tracking.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "UserErrors", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "DynamoDB Email Tracking"
        }
      },

      # SNS Topic Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.user_verification.name],
            [".", "NumberOfNotificationsFailed", ".", "."],
            [".", "NumberOfNotificationsDelivered", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "SNS User Verification Topic"
        }
      },

      # EC2 CPU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization (All Instances)"
        }
      },

      # Application Custom Metrics (from StatsD)
      {
        type = "metric"
        properties = {
          metrics = [
            ["CWAgent", "api.call.count", "Environment", var.environment],
            [".", "api.call.get_user.count", ".", "."],
            [".", "api.call.create_user.count", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Application API Calls"
        }
      }
    ]
  })
}

output "dashboard_url" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.application.dashboard_name}"
  description = "CloudWatch Dashboard URL"
}