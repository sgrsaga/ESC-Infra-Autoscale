output "public_subnet_ids" {
    value = data.aws_subnets.public_subnets.ids  
}