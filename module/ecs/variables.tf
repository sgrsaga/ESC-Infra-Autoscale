#### VPC Variables ####
variable "vpc_id" {
    type = string  
}

## MAX Running task count
variable "max_tasks" {
    type = number  
}

## MIN Running task count
variable "min_tasks" {
    type = number  
}

## EC2 AutoScaling AVG CPU threshold 
variable "asg_avg_cpu_target" {
    type = number  
}

## ECS Task AutoScaling AVG CPU threshold 
variable "ecs_task_avg_cpu_target" {
    type = number  
}