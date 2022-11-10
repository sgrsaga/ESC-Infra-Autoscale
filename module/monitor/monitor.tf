## Alerting for
# 1 Billing Alarm
# 2 ECS Cluster CPU utilization alert
# 3 ECS Cluster Memory utilization alert

# To Do
# 1 Create SNS Topic with with email addres linked
resource "aws_sns_topic" "cloud_watch_notify" {
  name = "CW_Alaerm_SNS_Topic"
  fifo_topic = false
}
# 2 Create subscription for the topic
resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = aws_sns_topic.cloud_watch_notify.arn
  protocol  = "email"
  endpoint  = var.email_address
  endpoint_auto_confirms = true
}

# Billing alarm
resource "aws_cloudwatch_metric_alarm" "Disk_Alert_Validator" {
  alarm_name          = "Billing Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period                    = "7200"
  statistic                 = "Maximum"
  threshold                 = "3"
  alarm_description         = "Billing amount exceed the threshold of $3 for the duration"
  actions_enabled           = true
  alarm_actions             = aws_sns_topic.cloud_watch_notify.arn
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

/*
## Disk Alerts for Validators
resource "aws_cloudwatch_metric_alarm" "Disk_Alert_Validator" {
  count = length(var.validators)
  alarm_name          = "${var.validators[count.index].Name} - Disk Utilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  dimensions = {
    InstanceId   = "${var.validators[count.index].ins_id}"
    ImageId = "${var.validators[count.index].ImageId}"
    #InstanceType = "${var.validators[count.index].ins_type}"
    path = var.path
    device = var.device
    fstype = var.validator_fs
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "85"
  alarm_description         = "${var.validators[count.index].Name} - Warning - Disk Utilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## Disk Alerts for Graph and IPFS AutoScaling Groups
resource "aws_cloudwatch_metric_alarm" "Disk_Alert_graph_ipfs_AutoScale" {
  count = length(var.graph_ipfs)
  alarm_name          = "${var.graph_ipfs[count.index].Name} - Disk Utilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  dimensions = {
    AutoScalingGroupName = "${var.graph_ipfs[count.index].AutoScaling}"
    InstanceId   = "${var.graph_ipfs[count.index].ins_id}"
    ImageId = "${var.graph_ipfs[count.index].ImageId}"
    InstanceType = "${var.graph_ipfs[count.index].ins_type}"
    path = var.path
    device = var.device
    fstype = var.graph_ipfs_fs
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "85"
  alarm_description         = "${var.graph_ipfs[count.index].Name} - Warning - Disk Utilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## Memory Alert Validators
resource "aws_cloudwatch_metric_alarm" "Memory_Alert_Validators" {
  count = length(var.validators)
  alarm_name          = "${var.validators[count.index].Name} - Memory Utilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  dimensions = {
    InstanceId   = "${var.validators[count.index].ins_id}"
    ImageId = "${var.validators[count.index].ImageId}"
    #InstanceType = "${var.validators[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "80"
  alarm_description         = "${var.validators[count.index].Name} - Warning - Memory Utilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## Memory Alert for Graph and IPFS AutoScaling Groups
resource "aws_cloudwatch_metric_alarm" "Memory_Alert_graph_ipfs_AutoScale" {
  count = length(var.graph_ipfs)
  alarm_name          = "${var.graph_ipfs[count.index].Name} - Memory Utilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  dimensions = {
    #AutoScalingGroupName = "${var.graph_ipfs[count.index].AutoScaling}"
    InstanceId   = "${var.graph_ipfs[count.index].ins_id}"
    #ImageId = "${var.graph_ipfs[count.index].ImageId}"
    #InstanceType = "${var.validators[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "80"
  alarm_description         = "${var.graph_ipfs[count.index].Name} - Warning - Memory Utilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}


## CPU Alerts validators
resource "aws_cloudwatch_metric_alarm" "CPUUtilization_Alert" {
  count = length(var.validators)
  alarm_name          = "${var.validators[count.index].Name} - CPUUtilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  dimensions = {
    InstanceId   = "${var.validators[count.index].ins_id}"
    #ImageId = "${var.validators[count.index].ImageId}"
    #InstanceType = "${var.validators[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "80"
  alarm_description         = "${var.validators[count.index].Name} - Warning - CPUUtilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## CPU Alerts Graph and IPFS AutoScaling
resource "aws_cloudwatch_metric_alarm" "CPUUtilization_Alert_graph_ipfs_AutoScale" {
  count = length(var.graph_ipfs)
  alarm_name          = "${var.graph_ipfs[count.index].Name} - CPUUtilization Alert"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "3"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  dimensions = {
    #AutoScalingGroupName = "${var.graph_ipfs[count.index].AutoScaling}"
    InstanceId   = "${var.graph_ipfs[count.index].ins_id}"
    #ImageId = "${var.graph_ipfs[count.index].ImageId}"
    #InstanceType = "${var.graph_ipfs[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "80"
  alarm_description         = "${var.graph_ipfs[count.index].Name} - Warning - CPUUtilization of the node reached 80% in last 5 minutes."
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## System Status Check for all servers 
resource "aws_cloudwatch_metric_alarm" "StatusCheckFailedSystem_Alert" {
  count = length(var.metric_filters)
  alarm_name          = "${var.metric_filters[count.index].Name} - System Status Check Failed Alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  dimensions = {
    #AutoScalingGroupName = "${var.metric_filters[count.index].AutoScaling}"
    InstanceId   = "${var.metric_filters[count.index].ins_id}"
    #ImageId = "${var.metric_filters[count.index].ImageId}"
    #InstanceType = "${var.metric_filters[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "0"
  alarm_description         = "${var.metric_filters[count.index].Name} - Critical - System Status Check Failed"
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

## Instance Status Check for all servers
resource "aws_cloudwatch_metric_alarm" "StatusCheckFailedInstance_Alert" {
  count = length(var.metric_filters)
  alarm_name          = "${var.metric_filters[count.index].Name} - Instance Status Check Failed Alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  dimensions = {
    #AutoScalingGroupName = "${var.metric_filters[count.index].AutoScaling}"
    InstanceId   = "${var.metric_filters[count.index].ins_id}"
    #ImageId = "${var.metric_filters[count.index].ImageId}"
    #InstanceType = "${var.metric_filters[count.index].ins_type}"
  }

  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "0"
  alarm_description         = "${var.metric_filters[count.index].Name} - Critical - Instance Status Check Failed"
  actions_enabled           = true
  alarm_actions             = var.sns_queue
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
}

######################## Database #########################
locals {
  thresholds = {
    BurstBalanceThreshold     = min(max(var.burst_balance_threshold, 0), 100)
    CPUUtilizationThreshold   = min(max(var.cpu_utilization_threshold, 0), 100)
    #CPUCreditBalanceThreshold = max(var.cpu_credit_balance_threshold, 0)
    DiskQueueDepthThreshold   = max(var.disk_queue_depth_threshold, 0)
    FreeableMemoryThreshold   = max(var.freeable_memory_threshold, 0)
    FreeStorageSpaceThreshold = max(var.free_storage_space_threshold, 0)
    SwapUsageThreshold        = max(var.swap_usage_threshold, 0)
    DatabaseConnections       = max(var.database_connections, 250)
  }
}

resource "aws_cloudwatch_metric_alarm" "burst_balance_too_low" {
  alarm_name          = "burst_balance_too_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BurstBalance"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["BurstBalanceThreshold"]
  alarm_description   = "Average database storage burst balance over last 10 minutes too low, expect a significant performance drop soon"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  alarm_name          = "cpu_utilization_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["CPUUtilizationThreshold"]
  alarm_description   = "Average database CPU utilization over last 10 minutes too high"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_queue_depth_too_high" {
  alarm_name          = "disk_queue_depth_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["DiskQueueDepthThreshold"]
  alarm_description   = "Average database disk queue depth over last 10 minutes too high, performance may suffer"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "freeable_memory_too_low" {
  alarm_name          = "freeable_memory_too_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["FreeableMemoryThreshold"]
  alarm_description   = "Average database freeable memory over last 10 minutes too low, performance may suffer"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space_too_low" {
  alarm_name          = "free_storage_space_threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["FreeStorageSpaceThreshold"]
  alarm_description   = "Average database free storage space over last 10 minutes too low"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "swap_usage_too_high" {
  alarm_name          = "swap_usage_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SwapUsage"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = local.thresholds["SwapUsageThreshold"]
  alarm_description   = "Average database swap usage over last 10 minutes too high, performance may suffer"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "DatabaseConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Maximum"
  threshold           = local.thresholds["DatabaseConnections"]
  alarm_description   = "Maximum Database Connections over last 10 minutes too high, performance may suffer"
  alarm_actions       = var.sns_queue
  ok_actions          = var.sns_queue

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

*/