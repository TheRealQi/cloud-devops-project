# Phase 4: Infrastructure Provisioning with Terraform

This phase provisions the complete AWS infrastructure using Terraform modules. The infrastructure includes networking (VPC), compute resources (Bastion and Jenkins servers), container registry (ECR), Kubernetes cluster (EKS), and cluster add-ons (Ingress and ArgoCD).

---
## AWS Architecture Diagram

![AWS Architecture Diagram](../images/aws_arch.png)

## Module Architecture Overview

The infrastructure is organized into 6 modules:

1. **Network (VPC)** - Provides the foundational networking layer
2. **Bastion** - Jump server for secure access to private resources
3. **Jenkins** - CI/CD automation server
4. **ECR** - Container image registry
5. **EKS** - Managed Kubernetes cluster
6. **Cluster Add-ons** - Kubernetes tooling (Ingress Controller, ArgoCD)

---

## 1. Network Module (VPC)

The network module creates a production-ready VPC with public and private subnets across multiple availability zones, following AWS best practices for high availability.

### 1.1 VPC Configuration

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}
```

**Purpose**: Creates the Virtual Private Cloud with DNS support enabled for service discovery and hostname resolution.

### 1.2 Subnet Architecture

The module creates two types of subnets distributed across availability zones:

**Public Subnets** - Host resources that need direct internet access (Bastion, NAT Gateways, Load Balancers)
```hcl
resource "aws_subnet" "public_subnet" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.project_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}
```

**Private Subnets** - Host internal resources (Jenkins, EKS worker nodes, application workloads)
```hcl
resource "aws_subnet" "private_subnet" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Name                              = "${var.project_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
```

**Key Feature**: Kubernetes-specific tags (`kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb`) allow EKS to automatically discover subnets for load balancer provisioning.

### 1.3 Internet Gateway

```hcl
resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}
```

**Purpose**: Provides internet connectivity for resources in public subnets.

### 1.4 NAT Gateways and Elastic IPs

```hcl
resource "aws_eip" "nat_eip" {
  for_each = local.public_subnets
  domain   = "vpc"
  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = local.public_subnets
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.key].id
  tags = {
    Name = "${var.project_name}-nat-${each.key}"
  }
  depends_on = [aws_internet_gateway.internet_gw]
}
```

**Purpose**: Each availability zone gets its own NAT Gateway with a dedicated Elastic IP, allowing private subnet resources to access the internet while remaining unreachable from the internet. This provides high availability - if one AZ fails, others continue functioning.

### 1.5 Route Tables

#### Public Route Table
| Destination | Target | Purpose |
|------------|--------|---------|
| 0.0.0.0/0 | Internet Gateway | Routes all internet-bound traffic through IGW |

```hcl
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  gateway_id             = aws_internet_gateway.internet_gw.id
  destination_cidr_block = "0.0.0.0/0"
}
```

**Association**: All public subnets use this single route table.

#### Private Route Tables (per AZ)
| Destination | Target | Purpose |
|------------|--------|---------|
| 0.0.0.0/0 | NAT Gateway (AZ-specific) | Routes internet traffic through the NAT Gateway in the same AZ |

```hcl
resource "aws_route_table" "private_rt" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route" "private_nat_route" {
  for_each               = local.private_subnets
  route_table_id         = aws_route_table.private_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[each.key].id
}
```

**Key Design**: Each private subnet has its own route table pointing to the NAT Gateway in its availability zone, ensuring traffic stays within the same AZ for better performance and fault isolation.

---

## 2. Bastion Module

The Bastion host serves as a secure jump server, providing SSH access to private resources (Jenkins, EKS cluster) while maintaining security best practices.

### 2.1 IAM Role and Policies

```hcl
resource "aws_iam_role" "bastion_role" {
  name = "${var.project_name}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
```

**Attached Policies**:
- **AmazonEC2ContainerRegistryPowerUser**: Allows pushing/pulling images to ECR
- **Custom EKS Management Policy**: Allows describing and accessing EKS clusters

```hcl
resource "aws_iam_policy" "bastion_eks_mgmt" {
  name        = "${var.project_name}-bastion-eks-mgmt"
  description = "Allows bastion to describe EKS clusters"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessConfig"
        ],
        Resource = "*"
      }
    ]
  })
}
```

### 2.2 EKS Access Configuration

```hcl
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.bastion_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.bastion_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
```

**Purpose**: Grants the Bastion host full administrative access to the EKS cluster, allowing kubectl commands and cluster management.

### 2.3 Security Group

| Rule Type | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Ingress | 22 | TCP | 0.0.0.0/0 | Allow SSH access from anywhere |
| Egress | All | All | 0.0.0.0/0 | Allow all outbound traffic |

```hcl
resource "aws_security_group" "bastion_sg" {
  name   = "${var.project_name}-bastion-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Note**: In production, restrict SSH ingress to specific IP ranges or use AWS Systems Manager Session Manager instead.

### 2.4 EC2 Instance

```hcl
resource "aws_instance" "bastion" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion-host"
  }
}
```

**Configuration**: 
- Deployed in a **public subnet** with a public IP
- Uses **t3.small** instance type
- Attached to IAM instance profile for AWS API access

### 2.5 Elastic IP

```hcl
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain   = "vpc"
  tags = {
    Name = "${var.project_name}-bastion-eip"
  }
}
```

**Purpose**: Provides a static public IP address that persists even if the instance is stopped/started, making it easier to whitelist and maintain SSH access.

---

## 3. Jenkins Module

The Jenkins module provisions a CI/CD automation server in a private subnet, accessible only through the Bastion host.

### 3.1 IAM Role and Policies

```hcl
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
```

**Purpose**: Grants Jenkins permissions to push Docker images to ECR during the build process.

### 3.2 Security Group

| Rule Type | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Ingress | 22 | TCP | Bastion SG | SSH access from Bastion only |
| Ingress | 8080 | TCP | VPC CIDR | Jenkins UI access from within VPC |
| Egress | All | All | 0.0.0.0/0 | Allow all outbound traffic |

```hcl
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Allow SSH Bastion host traffic"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Security Design**: Jenkins is isolated in a private subnet and only accessible via SSH through the Bastion host, following the principle of least privilege.

### 3.3 EC2 Instance Configuration

```hcl
resource "aws_instance" "jenkins" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }
  user_data = <<-EOF
              #!/bin/bash
              SWAP_SIZE=4G
              if [ ! -f /swapfile ]; then
                  fallocate -l $SWAP_SIZE /swapfile
                  chmod 600 /swapfile
                  mkswap /swapfile
                  swapon /swapfile
                  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
              fi
              EOF
  tags = {
    Name = "${var.project_name}-Jenkins-Server"
    Role = "jenkins-controller"
  }
}
```

**Key Features**:
- **50GB gp3 volume**: Provides sufficient storage for Jenkins builds and artifacts
- **4GB swap file**: Prevents OOM errors during memory-intensive builds
- **User data script**: Automatically configures swap on first boot
- **Deployed in private subnet**: Enhanced security posture

### 3.4 CloudWatch Monitoring

```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  dimensions = {
    InstanceId = aws_instance.jenkins.id
  }
}
```

**Purpose**: Alerts when CPU utilization exceeds 80% for 4 minutes (2 consecutive 2-minute periods), indicating potential resource constraints.

---

## 4. ECR Module

The Elastic Container Registry module creates a private Docker image repository for the application.

```hcl
resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}"
  image_tag_mutability = "MUTABLE"
}

output "repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}
```

**Configuration**:
- **Repository Name**: `finalprojectapp`
- **Tag Mutability**: MUTABLE - allows overwriting existing image tags
- **Output**: Exports repository URL for use in Jenkins pipelines

**Purpose**: Provides a secure, private registry for storing Docker images that will be deployed to EKS.

---

## 5. EKS Module

The EKS module provisions a managed Kubernetes cluster with worker nodes, following AWS best practices for security and scalability.

### 5.1 EKS Cluster IAM Role

```hcl
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
```

**Purpose**: Grants EKS control plane permissions to manage AWS resources (EC2, ELB, Route53, etc.).

### 5.2 EKS Cluster Security Group

| Rule Type | Port | Protocol | Source | Purpose |
|-----------|------|----------|--------|---------|
| Ingress | 443 | TCP | Bastion SG | kubectl access from Bastion |
| Ingress | 443 | TCP | 0.0.0.0/0 | Terraform/API access |
| Ingress | 443 | TCP | Self | Worker node to control plane communication |
| Egress | All | All | 0.0.0.0/0 | Allow all outbound traffic |

```hcl
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS Cluster Security Group"
  vpc_id      = var.vpc_id
  ingress {
    description     = "Allow access from Bastion SG"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }
  ingress {
    description = "Terraform from local"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow worker nodes to access EKS API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 5.3 EKS Cluster Configuration

```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}
```

**Key Configuration**:
- **Authentication Mode**: `API_AND_CONFIG_MAP` - supports both modern IAM-based access and legacy ConfigMap authentication
- **Endpoint Access**: Both private and public endpoints enabled for flexibility
- **Subnets**: Deployed across multiple private subnets for high availability

### 5.4 Worker Node IAM Role

```hcl
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
```

**Attached Policies**:
| Policy | Purpose |
|--------|---------|
| AmazonEKSWorkerNodePolicy | Core permissions for worker nodes |
| AmazonEKS_CNI_Policy | Allows VPC CNI plugin to manage networking |
| AmazonEC2ContainerRegistryReadOnly | Pull images from ECR |

### 5.5 Node Group Configuration

```hcl
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
  instance_types = ["t3.small"]
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
}
```

**Scaling Configuration**:
- **Desired**: 2 nodes for basic high availability
- **Minimum**: 1 node to reduce costs during low usage
- **Maximum**: 2 nodes (can be increased for production workloads)
- **Instance Type**: t3.small (2 vCPU, 2GB RAM)

### 5.6 EKS Access Management

```hcl
resource "aws_eks_access_entry" "terraform" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
```

**Purpose**: Grants the Terraform execution IAM principal (user/role) full administrative access to the EKS cluster.

---

## 6. Cluster Add-ons Module

This module deploys essential Kubernetes tooling using Helm charts.

### 6.1 NGINX Ingress Controller Deployment on the Cluster

```hcl
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 600
}
```

**Configuration Values**:

| Setting | Value | Purpose |
|---------|-------|---------|
| controller.service.type | LoadBalancer | Provisions AWS Classic Load Balancer |
| aws-load-balancer-type | classic | Uses Classic ELB (instead of NLB/ALB) |
| cross-zone-load-balancing | true | Distributes traffic across AZs |
| controller.metrics.enabled | true | Exposes Prometheus metrics |
| prometheus.io/scrape | true | Allows Prometheus to discover metrics |
| prometheus.io/port | 10254 | Metrics endpoint port |

**Purpose**: 
- Routes external HTTP/HTTPS traffic to services inside the cluster
- Creates an AWS Load Balancer automatically
- Provides SSL termination and path-based routing
- Exposes metrics for monitoring

### 6.2 ArgoCD Deployment on the Cluster

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.0.9"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    }
  ]
}
```

**Configuration**:
- **Service Type**: ClusterIP (internal-only, accessed via port-forward or Ingress)
- **Namespace**: Dedicated `argocd` namespace
- **Version**: 8.0.9

**Purpose**: 
- GitOps continuous deployment tool
- Automatically syncs Kubernetes manifests from Git repositories
- Provides declarative application management
- Offers a web UI for monitoring deployments

---

## 7. Main Terraform Configuration

The root `main.tf` orchestrates all modules and handles SSH key generation.

### 7.1 SSH Key Generation

```hcl
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
```

**Purpose**: Automatically generates SSH key pairs for Bastion and Jenkins, eliminating manual key management.

**Note**: The Jenkins key generation reuses the Bastion public/private key (likely a copy-paste error in the original code - in production, these should be separate keys).

### 7.2 Module Instantiation

The modules are instantiated in the following order:

1. **VPC Module** - Foundation networking
2. **Bastion Module** - Secure access point
3. **Jenkins Module** - CI/CD server (depends on VPC and Bastion)
4. **ECR Module** - Container registry
5. **EKS Module** - Kubernetes cluster (depends on VPC and Bastion)
6. **Cluster Add-ons** - Kubernetes tooling (depends on EKS)

```hcl
module "vpc" {
  source             = "./modules/network"
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.azs
  project_name       = var.project_name
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

module "k8s_addons" {
  source        = "./modules/cluster_addons"
  cluster_name  = module.eks.cluster_name
  vpc_id        = module.vpc.vpc_id
  region        = var.aws_region
  depends_on    = [module.eks]
}
```

---

## Infrastructure Summary

This Terraform configuration creates a complete, production-ready infrastructure with:

- **Multi-AZ high availability** across all layers
- **Secure network architecture** with public/private subnet separation
- **Defense in depth** with Bastion jump host and security group layering
- **Managed Kubernetes** with EKS for application hosting
- **CI/CD automation** with Jenkins in a private subnet
- **Container registry** with ECR for image storage
- **GitOps deployment** with ArgoCD
- **Ingress management** with NGINX for external access
- **Monitoring capabilities** with CloudWatch and Prometheus metrics

The infrastructure follows AWS best practices for security, scalability, and operational excellence.