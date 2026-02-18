
# Phase 5: Configuration Management with Ansible

This phase uses Ansible to automatically configure the Bastion and Jenkins servers provisioned by Terraform. Ansible handles software installation, configuration, and initial setup through Infrastructure as Code principles.

## Ansible Architecture Overview

The Ansible setup uses a **jump host pattern** where the Bastion server acts as an SSH proxy to reach the Jenkins server in the private subnet. This maintains security while enabling automated configuration.

```
Local Machine → Bastion (Public) → Jenkins (Private)
     │                │                    │
     └─ SSH ─────────┘                    │
          └────── SSH Proxy ──────────────┘

```

----------

## Directory Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── site.yaml                      # Main playbook
├── inventory/
│   ├── bastion_aws_ec2.yaml      # Dynamic inventory for Bastion
│   ├── jenkins_aws_ec2.yaml      # Dynamic inventory for Jenkins
│   └── group_vars/
│       ├── role_bastion_host.yaml      # Bastion connection config
│       └── role_jenkins_controller.yaml # Jenkins connection config
└── roles/
    ├── common/                    # Common utilities
    ├── docker/                    # Docker installation
    ├── java/                      # Java runtime
    ├── jenkins/                   # Jenkins setup
    ├── trivy/                     # Security scanner
    ├── aws_cli/                   # AWS CLI
    └── kubectl/                   # Kubernetes CLI

```

----------

## 1. Ansible Configuration

### ansible.cfg

```ini
[defaults]
inventory = inventory/
host_key_checking = False
remote_user = ubuntu
deprecation_warnings = False

[inventory]
enable_plugins = amazon.aws.aws_ec2

```

**Configuration Breakdown**:


| Setting             | Value                          | Purpose                                              |
|---------------------|--------------------------------|------------------------------------------------------|
| inventory           | inventory/                    | Points to directory containing dynamic inventory files |
| host_key_checking   | False                          | Disables SSH host key verification (acceptable for ephemeral infrastructure) |
| remote_user         | ubuntu                         | Default SSH user for Ubuntu AMI                      |
| deprecation_warnings| False                          | Suppresses Ansible deprecation messages              |
| enable_plugins      | amazon.aws.aws_ec2             | Enables AWS EC2 dynamic inventory plugin             |
**Purpose**: Sets global defaults and enables AWS EC2 dynamic inventory discovery.

----------

## 2. Dynamic Inventory Configuration

Ansible uses **dynamic inventory** to automatically discover EC2 instances based on tags, eliminating the need to manually maintain IP addresses.

### 2.1 Bastion Dynamic Inventory

**File**: `inventory/bastion_aws_ec2.yaml`

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  instance-state-name: running
  "tag:Role": bastion-host
keyed_groups:
  - key: tags.Role
    prefix: role
    separator: "_"
hostnames:
  - public_ip_address
compose:
  ansible_host: public_ip_address

```

**Configuration Breakdown**:


| Parameter          | Value                                | Purpose                                               |
|--------------------|--------------------------------------|-------------------------------------------------------|
| plugin             | amazon.aws.aws_ec2                   | Uses AWS EC2 dynamic inventory plugin                 |
| region             | us-east-1                            | Searches for instances in this region                |
| filters            | instance-state-name: running         | Only discovers running instances                      |
| filter             | tag:Role: bastion-host               | Only finds instances tagged with Role=bastion-host    |
| keyed_group        | tags.Role with prefix "role_"        | Creates group role_bastion_host                       |
| hostnames          | public_ip_address                    | Uses public IP as hostname                            |
| compose.ansible_host | public_ip_address                    | Sets Ansible connection target to public IP           |


**Result**: Creates an Ansible group called `role_bastion_host` containing all running Bastion instances.

### 2.2 Jenkins Dynamic Inventory

**File**: `inventory/jenkins_aws_ec2.yaml`

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  instance-state-name: running
  "tag:Role": jenkins-controller
keyed_groups:
  - key: tags.Role
    prefix: role
    separator: "_"
hostnames:
  - private_ip_address
compose:
  ansible_host: private_ip_address

```

**Key Difference from Bastion**: Uses `private_ip_address` instead of public IP since Jenkins is in a private subnet.

**Result**: Creates an Ansible group called `role_jenkins_controller` containing all running Jenkins instances.

----------

## 3. Connection Configuration (Jump Host Pattern)

### 3.1 Bastion Connection Variables

**File**: `inventory/group_vars/role_bastion_host.yaml`

```yaml
ansible_user: ubuntu
ansible_ssh_private_key_file: ../keys/bastion_admin.pem

```

**Direct Connection**:

-   **ansible_user**: SSH as ubuntu user
-   **ansible_ssh_private_key_file**: Uses Bastion's private key for authentication

**Purpose**: Establishes direct SSH connection to Bastion since it has a public IP.

----------

### 3.2 Jenkins Connection Variables (SSH ProxyJump)

**File**: `inventory/group_vars/role_jenkins_controller.yaml`

```yaml
ansible_user: ubuntu
ansible_ssh_private_key_file: "{{ playbook_dir }}/../keys/jenkins.pem"

ansible_ssh_common_args: |
  -o ForwardAgent=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ProxyCommand="ssh -i {{ playbook_dir }}/../keys/bastion_admin.pem -W %h:%p -q ubuntu@{{ hostvars[groups['role_bastion_host'][0]]['ansible_host'] }}"

```

**SSH ProxyCommand Breakdown**:

| SSH Option              | Value                           | Purpose                                                       |
|-------------------------|---------------------------------|---------------------------------------------------------------|
| ForwardAgent            | yes                             | Forwards SSH agent for multi-hop authentication               |
| StrictHostKeyChecking   | no                              | Skips host key verification (for dynamic IPs)                 |
| UserKnownHostsFile      | /dev/null                       | Doesn't save host keys (ephemeral infrastructure)             |
| ProxyCommand            | ssh -i bastion_key -W %h:%p bastion_ip | Uses Bastion as SSH jump host                                  |


**Understanding the ProxyCommand**:

```bash
ProxyCommand="ssh -i {{ playbook_dir }}/../keys/bastion_admin.pem -W %h:%p -q ubuntu@{{ hostvars[groups['role_bastion_host'][0]]['ansible_host'] }}"

```

**Component Breakdown**:

1.  **`ssh -i {{ playbook_dir }}/../keys/bastion_admin.pem`**
    
    -   SSH to Bastion using its private key
2.  **`-W %h:%p`**
    
    -   Forward connection to target host (%h) and port (%p)
    -   %h = Jenkins private IP (from dynamic inventory)
    -   %p = SSH port (22)
3.  **`-q`**
    
    -   Quiet mode (suppresses SSH messages)
4.  **`ubuntu@{{ hostvars[groups['role_bastion_host'][0]]['ansible_host'] }}`**
    
    -   Connect to the first Bastion instance's IP (from dynamic inventory)
    -   `hostvars` = All host variables in inventory
    -   `groups['role_bastion_host'][0]` = First host in bastion group
    -   `['ansible_host']` = The public IP assigned by dynamic inventory

**Visual Connection Flow**:

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Local         │         │   Bastion        │         │   Jenkins       │
│   Machine       │────────>│   (Public)       │────────>│   (Private)     │
│                 │  SSH    │   Public Subnet  │  SSH    │   Private Subnet│
└─────────────────┘         └──────────────────┘         └─────────────────┘
     Uses                       Acts as                      Final target
  bastion_admin.pem            jump host                    jenkins.pem
  (to reach bastion)        (proxies traffic)            (to authenticate)

```

**Step-by-Step Connection Process**:

1.  Ansible initiates SSH to Jenkins private IP
2.  Instead of connecting directly, SSH uses ProxyCommand
3.  ProxyCommand opens SSH connection to Bastion (using bastion_admin.pem)
4.  Bastion forwards the connection to Jenkins private IP using `-W` flag
5.  Jenkins authenticates the connection using jenkins.pem
6.  Ansible commands flow through: `Local → Bastion → Jenkins`

**Why This Works**:

-   Bastion is in a **public subnet** with a public IP (directly reachable)
-   Jenkins is in a **private subnet** with no public IP (unreachable from internet)
-   Bastion has network access to Jenkins via VPC routing
-   ProxyCommand creates an **SSH tunnel** through Bastion to reach Jenkins

----------

## 4. Main Playbook

**File**: `site.yaml`

```yaml
---
- name: Configure Bastion Host
  hosts: role_bastion_host
  become: yes
  remote_user: ubuntu
  roles:
    - common
    - docker
    - aws_cli
    - kubectl

- name: Configure Jenkins Controller Server
  hosts: role_jenkins_controller
  become: yes
  remote_user: ubuntu
  roles:
    - common
    - java
    - docker
    - trivy
    - aws_cli
    - jenkins

```

**Playbook Structure**:

### Play 1: Configure Bastion Host

| Setting          | Value                 | Purpose                                         |
|------------------|-----------------------|-------------------------------------------------|
| name             | Configure Bastion Host | Descriptive name for the play                  |
| hosts            | role_bastion_host      | Targets instances in bastion dynamic group     |
| become           | yes                    | Uses sudo for privileged operations            |
| remote_user      | ubuntu                 | SSH user for Ubuntu AMI                        |



**Bastion Roles** (in execution order):


| Role             | Purpose                                        |
|------------------|------------------------------------------------|
| common           | Installs essential utilities (git, curl, wget, etc.) |
| docker           | Installs Docker for container operations       |
| aws_cli          | Installs AWS CLI for EKS/ECR access            |
| kubectl          | Installs kubectl for Kubernetes management     |


### Play 2: Configure Jenkins Controller Server


| Setting          | Value                    | Purpose                                         |
|------------------|--------------------------|-------------------------------------------------|
| name             | Configure Jenkins Controller Server | Descriptive name for the play                  |
| hosts            | role_jenkins_controller   | Targets instances in Jenkins dynamic group     |
| become           | yes                       | Uses sudo for privileged operations            |
| remote_user      | ubuntu                    | SSH user for Ubuntu AMI                        |


**Jenkins Roles** (in execution order):

| Role             | Purpose                                        |
|------------------|------------------------------------------------|
| common           | Installs essential utilities                  |
| java             | Installs OpenJDK (Jenkins dependency)          |
| docker           | Installs Docker (for building images)         |
| trivy            | Installs security scanner for image vulnerabilities |
| aws_cli          | Installs AWS CLI (for pushing to ECR)          |
| jenkins          | Installs and configures Jenkins CI/CD server  |