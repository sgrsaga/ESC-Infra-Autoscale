## Alerting for
# 1 ECS Cluster CPU utilization alert
# 2 ECS Cluster Memory utilization alert

# To Do
# 1 Create SNS Topic to publish notifications
resource "aws_sns_topic" "cloud_watch_notify" {
  name = "CW_Alaerm_SNS_Topic"
  fifo_topic = false
}
# 2 Create email subscription for the topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cloud_watch_notify.arn
  protocol  = "email"
  endpoint  = var.delivery_email
  endpoint_auto_confirms = true
}

# Get the Account ID
data "aws_caller_identity" "current" {}
output "account_id" {
    value = data.aws_caller_identity.current.account_id  
}
# Billing alarm
resource "aws_cloudwatch_metric_alarm" "Billing_Alarm" {
  alarm_name = "Billing Alarm" #
  comparison_operator = "GreaterThanOrEqualToThreshold" #
  evaluation_periods  = "1" #
  metric_name = "EstimatedCharges" #
  namespace = "AWS/Billing" #
  period = "21600" #
  statistic = "Maximum" #
  threshold = "3" #
  alarm_description = "Billing amount exceed the threshold of $3 for the duration" #
  alarm_actions = ["${aws_sns_topic.cloud_watch_notify.arn}"] #

  dimensions = {
    Currency = "USD" #
  }
}


## ECS Cluster CPU utilization alert
resource "aws_cloudwatch_metric_alarm" "ECS_Cluster_CPU" {
  alarm_name          = "ECS Cluster CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "2"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period                    = "300"
  statistic                 = "Maximum"
  threshold                 = "0.003"
  alarm_description         = "ECS Cluster CPU exceed the threshold for the duration"
  actions_enabled           = true
  alarm_actions             = ["${aws_sns_topic.cloud_watch_notify.arn}"]
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
  dimensions = {
    ClusterName = "project_cluster"
    ServiceName = "service_node_app"
  }
}

## ECS Cluster CPU utilization alert
resource "aws_cloudwatch_metric_alarm" "ECS_Cluster_MEM" {
  alarm_name          = "ECS Cluster MemoryUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "2"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period                    = "300"
  statistic                 = "Maximum"
  threshold                 = "0.15"
  alarm_description         = "ECS Cluster Memory exceed the threshold for the duration"
  actions_enabled           = true
  alarm_actions             = ["${aws_sns_topic.cloud_watch_notify.arn}"]
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
  dimensions = {
    ClusterName = "project_cluster"
    ServiceName = "service_node_app"
  }
}
