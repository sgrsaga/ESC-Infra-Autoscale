########## Create dependancy service for ECS Cluster service

## Get Public Security Group to apply for the Database
data "aws_security_group" "public_sg" {
  tags = {
    Name = "PUBLIC_SG"
  }
}

## Get Public SubnetList
data "aws_subnets" "public_subnets" {
    filter {
      name = "tag:Access"
      values = ["PUBLIC"]
    }
}

############## Use available roles to link to user or service
data "aws_iam_role" "role_ecsServiceRole" {
  name = "ecsServiceRole"
}
data "aws_iam_role" "role_ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
}
data "aws_iam_role" "role_ecsAutoscaleRole" {
  name = "ecsAutoscaleRole"
}
data "aws_iam_role" "role_ecsInstanceRole" {
  name = "ecsInstanceRole"
}

# Create Instance Profile for ECS EC2 instances to use in Launch Configuration
resource "aws_iam_instance_profile" "ecs_agent_profile" {
  name = "ecs-agent"
  role = data.aws_iam_role.role_ecsInstanceRole.name
}

################### S3 bucket for access_logs
resource "aws_s3_bucket" "lb_logs" {
  bucket = "alb-access-logs-proj-test-20221110"

  tags = {
    Name        = "ALB_LOG_Bucket"
    Environment = "alb"
  }
}
/*
resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.lb_logs.id
  acl    = "private"
}
*/
##
## GEt the service Account ID
data "aws_elb_service_account" "service_account_id" {}
## Get the callert identity
data "aws_caller_identity" "caller_identity" {}

## Get the policy to allow PutObject permissions to service account
data "aws_iam_policy_document" "allow_alb_write_perm" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["${data.aws_elb_service_account.service_account_id.arn}"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.lb_logs.arn}/alb_logs/AWSLogs/${data.aws_caller_identity.caller_identity.account_id}/*",
    ]
  }
}

## Apply bucket policy to the bucket
resource "aws_s3_bucket_policy" "access_logs_policy" {
    bucket = "${aws_s3_bucket.lb_logs.id}"
    policy = data.aws_iam_policy_document.allow_alb_write_perm.json
}

## Enable SSE for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = "${aws_s3_bucket.lb_logs.bucket}"

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
###############################################

# Create Application Load balancer
resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.public_sg.id]
  subnets            = data.aws_subnets.public_subnets.ids
  ip_address_type = "ipv4"

  enable_deletion_protection = false
  tags = {
    Environment = "Project"
  }
  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "access-lb"
    enabled = true
  }
  depends_on = [
    aws_s3_bucket.lb_logs,
    aws_s3_bucket_policy.access_logs_policy
  ]
}

# Target Group for ALB
resource "aws_lb_target_group" "ecs_alb_tg" {
  name     = "ecs-alb-tg"
  target_type = "instance"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    healthy_threshold   = "5"
    interval            = "30"
    unhealthy_threshold = "2"
    timeout             = "20"
    path                = "/"
  }
}


# Links ALB to TG with lister rule
resource "aws_lb_listener" "alb_to_tg" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    #target_group_arn = aws_lb_target_group.ecs_alb_tg.id
    type = "redirect"

    redirect {
      port = 443
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Create ECR repository for the image to store
resource "aws_ecr_repository" "project_repo" {
  name = "project_repo_aws"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Create ECS Cluster
resource "aws_ecs_cluster" "project_cluster" {
  name = "project_cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task definitions to use in Service
resource "aws_ecs_task_definition" "project_task" {
  family = "project_task"
  execution_role_arn = data.aws_iam_role.role_ecsTaskExecutionRole.arn
  container_definitions = jsonencode([
    {
      name      = "AppTask"
      image     = aws_ecr_repository.project_repo.repository_url
      cpu       = 200
      memory    = 300
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 8000
        }
      ]
    }
  ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }
  depends_on = [
    aws_ecr_repository.project_repo
  ]
}

## Create EC2 Launch Configuration for the AutoScaling Group
resource "aws_launch_configuration" "ecs_ec2_launch_config" {
  image_id = "ami-03dbf0c122cb6cf1d"
  iam_instance_profile = aws_iam_instance_profile.ecs_agent_profile.name
  security_groups = [data.aws_security_group.public_sg.id]
  instance_type = "t2.micro"
  key_name = "EcsKey"
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
  #!/bin/bash
  cat <<'EOF' >> /etc/ecs/ecs.config
  ECS_CLUSTER=project_cluster
  ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance
  EOF  
}

## Create Autoscaling group
resource "aws_autoscaling_group" "ecs_ec2_autosacaling_group" {
  name = "ecs-ec2-asg"
  vpc_zone_identifier = data.aws_subnets.public_subnets.ids
  launch_configuration = aws_launch_configuration.ecs_ec2_launch_config.name

  desired_capacity = 6
  min_size = 6
  max_size = 12
  health_check_grace_period = 300
  health_check_type = "EC2"
  
  depends_on = [
    aws_launch_configuration.ecs_ec2_launch_config
  ]
}

## Auto Scaling plan
resource "aws_autoscalingplans_scaling_plan" "ec2_scaling_plan" {
  name = "ec2_scaling_plan"
  application_source {
    tag_filter {
      key    = "Project"
      values = ["ScalingEC2s"]
    }
  }
  scaling_instruction {
    max_capacity       = 15
    min_capacity       = 2
    resource_id        = format("autoScalingGroup/%s", aws_autoscaling_group.ecs_ec2_autosacaling_group.name)
    scalable_dimension = "autoscaling:autoScalingGroup:DesiredCapacity"
    service_namespace  = "autoscaling"

    target_tracking_configuration {
      predefined_scaling_metric_specification {
        predefined_scaling_metric_type = "ASGAverageCPUUtilization"
      }

      target_value = 70
    }
  }
}


# ECS Service configuration - This block maintain the link between all services.
resource "aws_ecs_service" "service_node_app" {
  name            = "service_node_app"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.project_task.arn
  desired_count   = 3
  launch_type = "EC2"
  health_check_grace_period_seconds = 300
  iam_role        = data.aws_iam_role.role_ecsServiceRole.arn
  depends_on      = [
    aws_ecs_cluster.project_cluster, 
    aws_ecs_task_definition.project_task,
    aws_lb_listener.alb_to_tg
    ]
  lifecycle {
    ignore_changes = [desired_count]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_alb_tg.arn
    container_name   = "AppTask"
    container_port   = 80
  }
}

# Autoscaling for ECS Service instances
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.project_cluster.name}/${aws_ecs_service.service_node_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Autoscaling policy - If the CPU level above 70% it will scale up.
resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "scale_in_out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 70
    scale_out_cooldown = 120
    scale_in_cooldown = 120
  }
}