terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.32.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
  }
  backend "s3" {
    bucket  = "tf-rs-828343277455"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
