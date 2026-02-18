resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_generated_key" {
  key_name   = var.bastion_key_name
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

resource "local_file" "bastion_private_key" {
  filename        = "${path.module}/../keys/${var.bastion_key_name}.pem"
  content         = tls_private_key.bastion_ssh_key.private_key_pem
  file_permission = "0600"
}

resource "tls_private_key" "jenkins_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins_generated_key" {
  key_name   = var.jenkins_key_name
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

resource "local_file" "jenkins_private_key" {
  filename        = "${path.module}/../keys/${var.jenkins_key_name}.pem"
  content         = tls_private_key.bastion_ssh_key.private_key_pem
  file_permission = "0600"
}

module "vpc" {
  source             = "./modules/network"
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.azs
  project_name       = var.project_name
}

module "jenkins" {
  source        = "./modules/jenkins"
  vpc_id        = module.vpc.vpc_id
  vpc_cidr      = var.vpc_cidr
  subnet_id     = module.vpc.private_subnets[0]
  instance_type = "t3.small"
  ami           = "ami-0b6c6ebed2801a5cb"
  key_name      = aws_key_pair.jenkins_generated_key.key_name
  bastion_sg_id = module.bastion.security_group_id
  project_name  = var.project_name
}

module "ecr" {
  source   = "./modules/ecr"
  app_name = "finalprojectapp"
}

module "eks" {
  source        = "./modules/eks"
  vpc_id        = module.vpc.vpc_id
  cluster_name  = "${var.project_name}-cluster"
  subnet_ids    = module.vpc.private_subnets
  bastion_sg_id = module.bastion.security_group_id
}

module "bastion" {
  source           = "./modules/bastion"
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnets[0]
  eks_cluster_name = module.eks.cluster_name
  instance_type    = "t3.small"
  ami              = "ami-0b6c6ebed2801a5cb"
  key_name         = aws_key_pair.bastion_generated_key.key_name
  project_name     = var.project_name
}

module "k8s_addons" {
  source = "./modules/cluster_addons"
  cluster_name      = module.eks.cluster_name
  vpc_id            = module.vpc.vpc_id
  region            = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
  depends_on = [module.eks]
}
