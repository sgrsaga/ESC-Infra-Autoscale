/*
## Refer main_network Module
module "main_network" {
  source = "../main_network"
}
*/

## Get Private SubnetList
data "aws_subnet_ids" "private_subnets" {
  vpc_id = var.vpc_id
  tags = {
    Access = "PRIVATE"
  }
}

## Get Private Security Group
data "aws_security_group" "private_sg" {
  tags = {
    Name = "PRIVATE_SG"
  }
}


## Create subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = var.db_subnet_group_name
  subnet_ids = data.aws_subnet_ids.private_subnets.ids
  tags = {
    Name = var.db_subnet_group_name
  }
}

## Create Password
resource "random_password" "db_master_pass"{
  length           = 12
  special          = true
  override_special = "_!%^"
}
## Create secret in Password manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "postgres-db-password"
}
## Set the secret version
resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_pass.result
}

## Get the password with name
data "aws_secretsmanager_secret" "get_db_password" {
  name = "postgres-db-password"
  depends_on = [
    aws_secretsmanager_secret.db_password,
    aws_secretsmanager_secret_version.password
  ]
}
## Get the Secret ID
data "aws_secretsmanager_secret_version" "get_password_version" {
  secret_id = data.aws_secretsmanager_secret.get_db_password.id
  depends_on = [
    aws_secretsmanager_secret.db_password,
    aws_secretsmanager_secret_version.password
  ]
}

## Create a Monitoring role
resource "aws_iam_role" "rds_role" {
  name = "rds_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })
}

## Creating ppolicy
resource "aws_iam_role_policy" "rds_policy" {
  name = "rds_policy"
  role = aws_iam_role.rds_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


## Create Postgres Database Instance
resource "aws_db_instance" "postgress_database" {
    identifier = var.db_identifier
    allocated_storage = var.db_storage
    max_allocated_storage = var.max_allocated_storage_value
    engine = var.db_engine
    engine_version = var.db_engine_version
    instance_class = var.db_class
    name = var.db_name
    username = var.db_username
    password = data.aws_secretsmanager_secret_version.get_password_version.secret_string
    #password = data.aws_secretsmanager_secret_version.password
    #password = aws_secretsmanager_secret_version.password.secret_string
    #parameter_group_name = var.db_para_group_name
    storage_encrypted = var.is_storage_encrypted
    storage_type = var.db_storage_type
    backup_retention_period = var.db_backup_retention_period
    multi_az = var.muli_az_enable
    db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
    vpc_security_group_ids = [data.aws_security_group.private_sg.id]
    iam_database_authentication_enabled = true
    final_snapshot_identifier = "final-snap"
    skip_final_snapshot = false
    copy_tags_to_snapshot = true
    monitoring_role_arn = aws_iam_role.rds_role.arn
    monitoring_interval = 60
    enabled_cloudwatch_logs_exports = ["postgresql"]
    deletion_protection = var.db_delete_protect
    depends_on = [aws_db_subnet_group.db_subnet_group, random_password.db_master_pass, aws_secretsmanager_secret.db_password, aws_secretsmanager_secret_version.password]
}

