########## Create dependancy service for ECS Cluster service
#  Application Load balancer
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


resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.public_sg.id]
  subnets            = data.aws_subnets.public_subnets.ids
  ip_address_type = "ipv4"

  enable_deletion_protection = false
  tags = {
    Environment = "Test"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "ecs_alb_tg" {
  name     = "ecs-alb-tg"
  target_type = "instance"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# Links ALB to TG with lister rule
resource "aws_lb_listener" "alb_to_tg" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.ecs_alb_tg.id
    type = "forward"
  }
}

################# Role for Launch Config ##################
resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
  EOF
}
resource "aws_iam_policy" "ecs_ec2_policy" {
  name        = "test-policy"
  description = "A test policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeTags",
                "ecs:CreateCluster",
                "ecs:DeregisterContainerInstance",
                "ecs:DiscoverPollEndpoint",
                "ecs:Poll",
                "ecs:RegisterContainerInstance",
                "ecs:StartTelemetrySession",
                "ecs:UpdateContainerInstancesState",
                "ecs:Submit*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = aws_iam_policy.ecs_ec2_policy.arn
}

resource "aws_iam_instance_profile" "ecs_agent_profile" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

###########################################################


## Create EC2 Launch Configuration
resource "aws_launch_configuration" "ecs_ec2_launch_config" {
  name = "ECS-EC2-Launch-Config"
  image_id = "ami-03dbf0c122cb6cf1d"
  iam_instance_profile = aws_iam_instance_profile.ecs_agent_profile.name
  security_groups = [data.aws_security_group.public_sg.id]
  instance_type = "t2.micro"
  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
  #!/bin/bash
  sudo yum update -y
  sudo amazon-linux-extras disable docker
  sudo amazon-linux-extras install -y ecs
  sudo systemctl enable ecs
  sudo mkdir -p /etc/ecs/
  cd /etc/ecs/
  sudo chown ec2-user:ec2-user -R ./ecs/
  sudo echo ECS_CLUSTER=project_cluster >> /etc/ecs/ecs.config
  sudo systemctl restart ecs
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

############## Use available roles
data "aws_iam_role" "role_ecsServiceRole" {
  name = "ecsServiceRole"
}
data "aws_iam_role" "role_ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
}
data "aws_iam_role" "role_ecsAutoscaleRole" {
  name = "ecsAutoscaleRole"
}


# Create ECR repository for the image to store
resource "aws_ecr_repository" "project_repo" {
  name                 = "project_repo_aws"
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
      cpu       = 10
      memory    = 512
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

# Service configuration
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

# Autoscaling for ECS Service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.project_cluster.name}/${aws_ecs_service.service_node_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Autoscaling policy
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