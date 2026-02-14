variable "aws_region" {
  default = "us-east-1"
  type = string
}

variable "project_name" {
  default = "ivolve-project"
  type = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  type = string
}
