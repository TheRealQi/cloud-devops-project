variable "vpc_cidr" {
  type = string

}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == length(var.public_subnets)
    error_message = "The Number of AZs must match the number of public subnets"
  }
}

variable "project_name" {
  type = string
}
