module "vpc" {
  source = "./modules/network"
  vpc_cidr = "${var.vpc_cidr}"
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
  project_name = "${var.project_name}"
}

module "server" {
  source           = "./modules/server"
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnets[0]
  instance_type    = "t3.micro"
  key_name         = "jenkins-controller-ssh"
  project_name     = var.project_name
}