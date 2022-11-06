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