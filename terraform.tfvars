# 1. Create a VPC
vpc_name = "Project_VPC"
vpc_cidr = "10.0.0.0/16"
public_source_cidr = ["0.0.0.0/0"]
public_source_cidr_v6 = ["::/0"]
#azs = ["ap-south-1a","ap-south-1b","ap-south-1c"]

# 2. Create a Internet Gateway
ig_name = "Project_IG"

# 1.3. Create 2 Route tables
public_rt = "PUBLIC_RT"
private_rt = "PRIVATE_RT"

# 1.4. Create 3 Public Subnets
public_subnets = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24","10.0.4.0/24","10.0.5.0/24","10.0.6.0/24","10.0.7.0/24"]
# 1.5. Create 3 Private Subnets
private_subnets = ["10.0.8.0/24","10.0.9.0/24","10.0.10.0/24","10.0.11.0/24","10.0.12.0/24","10.0.13.0/24","10.0.14.0/24"]

# 1.6. Create Public access Security Group
public_access_sg_ingress_rules = [
    {
      protocol = "tcp"
      from_port = 80
      to_port = 80
    },
    {
      protocol = "tcp"
      from_port = 443
      to_port = 443
    },
    {
      protocol = "tcp"
      from_port = 22
      to_port = 22
    },
    {
      protocol = "-1"
      from_port = 0
      to_port = 0
    }
  ]