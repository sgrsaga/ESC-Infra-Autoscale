output "public_subnet_ids" {
    value = data.aws_subnets.public_subnets.ids  
}


## Project Cluster name
output "ecs_cluster_name" {
    value = aws_ecs_cluster.project_cluster.name
}

## ECS Service name
output "ecs_service_name" {
    value = aws_ecs_service.service_node_app.name
}


## Target group will refered in R53 whe adding a new HTTPS listner
output "lb_target_group" {
  value = aws_lb_target_group.ecs_alb_tg  
}

## Output AWS ALB ARN
output "ecs_lb" {
  value = aws_lb.ecs_lb.arn
}
