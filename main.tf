## Add the provide section.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"  ## was 3.65.0
    }
  }
}

## Setting the AWS S3 as the Terraform backend
terraform {
  backend "s3" {
    bucket = "terraform-state-file-20221104-terracode"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = "us-east-1"
}


## 1. Call IAM user create module to create user profile for profbob
module "iam" {
  source = "./module/iam"
  
}

## 2. Call the Network module to generate VPC components
module "main_network" {
  source = "./module/network"
  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr
  public_source_cidr = var.public_source_cidr
  public_source_cidr_v6 = var.public_source_cidr_v6
  ig_name = var.ig_name

  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  public_access_sg_ingress_rules = var.public_access_sg_ingress_rules
  public_rt = var.public_rt
  private_rt = var.private_rt
}
/*
## 3. Call Databse creation module
module "pg_database" {
  source = "./module/rds"
  db_identifier = var.db_identifier
  vpc_id = module.main_network.vpc_id
  db_name = var.db_name
  depends_on = [module.main_network] 
}
*/
## 4. Call ECS creation module
module "ecs_cluster" {
  source = "./module/ecs"
  vpc_id = module.main_network.vpc_id
  depends_on = [module.main_network] 
}

## 4.1 Call ECS service autoscaling module
module "ecs-service-autoscaling" {
  source  = "cn-terraform/ecs-service-autoscaling/aws"
  version = "1.0.6"
  name_prefix = "Project_prefix"
  ecs_service_name = module.ecs_cluster.ecs_service_name
  ecs_cluster_name = module.ecs_cluster.ecs_cluster_name
  # insert the 3 required variables here
  depends_on = [module.ecs_cluster]
}