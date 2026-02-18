
# End-to-End Cloud DevOps \& GitOps Pipeline 

This project demonstrates a complete **Cloud DevOps** lifecycle, from application containerization and infrastructure provisioning to automated GitOps deployments. Below is a summary of the project phases, architecture, and results.

## Project Phases

-   [Phase 1 & 2: Application Development & Containerization](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/app)
    
-   [Phase 3: Kubernetes Manifests](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/k8s)
    
-   [Phase 4: Infrastructure as Code (Terraform)](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/terraform)
    
-   [Phase 5: Configuration Management (Ansible)](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/ansible)
    
-   [Phase 6: Continuous Integration (Jenkins)](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/jenkins)
    
-   [Phase 7: Continuous Deployment (ArgoCD)](https://github.com/TheRealQi/CloudDevOpsProject/tree/main/argocd)

----------

## 1. General Architecture & Flow
![Jenkins Pipeline Success](images/arch.png)

## 2. Jenkins Pipeline Success
![Jenkins Pipeline Success](images/pipeline_success.png)
### ECR Repo
![ECR Repo After Jenkins Pipeline Success](images/ecr_repo.png)
## 3. ArgoCD Sync Status
![ArgoCD Dashboard](images/argocd_dashboard.png)
## 4. Application Access
![Application Access](images/application_access.png)