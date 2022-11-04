## Add the provide section.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.65.0"  ## was 3.64.2
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
