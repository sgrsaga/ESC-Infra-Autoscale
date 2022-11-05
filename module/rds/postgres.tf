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

## Get the password
data "aws_secretsmanager_secret" "db_password" {
  name = "postgres-db-password"
  depends_on = [
    aws_secretsmanager_secret.db_password,
    aws_secretsmanager_secret_version.password
  ]
}

data "aws_secretsmanager_secret_version" "password" {
  secret_id = data.aws_secretsmanager_secret.db_password
  depends_on = [
    aws_secretsmanager_secret.db_password,
    aws_secretsmanager_secret_version.password
  ]
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
    password = data.aws_secretsmanager_secret_version.password
    #password = data.aws_secretsmanager_secret_version.password
    #password = aws_secretsmanager_secret_version.password.secret_string
    #parameter_group_name = var.db_para_group_name
    storage_encrypted = var.is_storage_encrypted
    storage_type = var.db_storage_type
    backup_retention_period = var.db_backup_retention_period
    multi_az = var.muli_az_enable
    db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
    vpc_security_group_ids = var.vpc_security_group_ids
    iam_database_authentication_enabled = true
    final_snapshot_identifier = "final-snap"
    skip_final_snapshot = false
    copy_tags_to_snapshot = true
    monitoring_role_arn = var.monitoring_role
    monitoring_interval = 60
    enabled_cloudwatch_logs_exports = ["postgresql"]
    deletion_protection = var.db_delete_protect
    depends_on = [aws_db_subnet_group.db_subnet_group, random_password.db_master_pass, aws_secretsmanager_secret.db_password, aws_secretsmanager_secret_version.password]
}

