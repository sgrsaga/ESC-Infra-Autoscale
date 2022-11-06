########## Create dependancy service for ECS Cluster service
# 01. ECS ecsTaskExecutionRole
# 02. ECS ecsServiceRole

## Create a Monitoring role
resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "ecs.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      },
    ]
  })
}

## Creating policy
resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs_policy"
  role = aws_iam_role.ecs_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
	Version: "2012-10-17",
	Statement: [
		{
			Sid: "manual",
			Effect: "Allow",
			Action: [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:Describe*",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:Describe*",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:RegisterTargets"
			],
			Resource: "*"
		}
	]
})
  depends_on = [
    aws_iam_role.ecs_role
  ]
}

# 03. Application Load balancer
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


## Get the service account for S3 access
data "aws_elb_service_account" "main" {}

## Create S3 bucket for Access logs
resource "aws_s3_bucket" "alb_access_log_s3" {
  bucket = "kc4n2i7lgqsiyvundstess-test-project"
  force_destroy = true
  tags = {
    Name = "ALB-Access-Log"
  }
  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY
}



/*
## S3 bucket acl
resource "aws_s3_bucket_acl" "lb_access_logs_acl" {
  bucket = aws_s3_bucket.alb_access_log_s3.id
  acl    = "private"
}

## Set Policy
data "aws_iam_policy_document" "allow_s3_lb" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elb.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.alb_access_log_s3.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
  }
}

# AWS S3 bucket policy setup
resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.alb_access_log_s3.id
  policy = data.aws_iam_policy_document.allow_s3_lb.json
}
*/

resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.public_sg.id]
  subnets            = data.aws_subnets.public_subnets.ids

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_access_log_s3.bucket
    prefix  = "alb-access-log"
    enabled = true
  }

  tags = {
    Environment = "Test"
  }
}

# 04. Target Group for ALB
resource "aws_lb_target_group" "ecs_alb_tg" {
  name     = "ecs-alb-tg"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# 05. Create ECR repository for the image to store
resource "aws_ecr_repository" "project_repo" {
  name                 = "project_repo_aws"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 06. Create ECS Cluster
resource "aws_ecs_cluster" "project_cluster" {
  name = "project_cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 07. Task definitions to use in Service
resource "aws_ecs_task_definition" "project_task" {
  family = "project_task"
  execution_role_arn = aws_iam_role.ecs_role.arn
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
          hostPort      = 80
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

# 08. Service configuration
resource "aws_ecs_service" "service_node_app" {
  name            = "service_node_app"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.project_task.arn
  desired_count   = 3
  iam_role        = aws_iam_role.ecs_role.arn
  depends_on      = [aws_iam_role_policy.ecs_policy, aws_ecs_cluster.project_cluster, aws_ecs_task_definition.project_task]

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_alb_tg.arn
    container_name   = "AppTask"
    container_port   = 80
  }
  
}
