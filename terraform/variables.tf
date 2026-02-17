variable "aws_region" {
  default = "us-east-1"
  type = string
}

variable "project_name" {
  default = "ivolve-final-project"
  type = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  type = string
}

variable "bastion_key_name" {
  default = "bastion_admin"
  type = string
}

variable "jenkins_key_name" {
  default = "jenkins"
  type = string
}

variable "public_subnets" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
  type = list(string)
}

variable "private_subnets" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
  type = list(string)
}

variable "azs" {
  default = ["us-east-1a", "us-east-1b"]
  type = list(string)
}
