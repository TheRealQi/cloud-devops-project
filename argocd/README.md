
# Phase 7: Continuous Deployment with ArgoCD

This phase implements the **GitOps** deployment strategy. ArgoCD monitors the application repository for changes made by the Jenkins pipeline in the previous phase. Once a change is detected in the Kubernetes manifests, ArgoCD automatically synchronizes the cluster state with the desired state defined in Git.

----------


## 0. ArgoCD Dashboard Access

Because the management cluster is in a private subnet, access requires an SSH tunnel through the Bastion host followed by a Kubernetes port-forward.

### Step 1: Create SSH Tunnel

Run this on your **local machine** to bridge your local port 8081 to the Bastion host:

`ssh -i bastion_admin.pem -L 8081:localhost:8081 ubuntu@3.215.75.84`

### Step 2: Port-Forward to Service

Once logged into the **Bastion host**, run the following to forward the service traffic to the tunnel:

`kubectl port-forward svc/argocd-server -n argocd 8081:443`

### Step 3: Access UI

Open your browser and navigate to: `https://localhost:8081`

> **Credentials:** > * **Username:** `admin`
> 
> -   **Password:** Retrieve via: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
>

----------

## 1. ArgoCD Application Manifest

The following `argocd-application.yaml` defines the connection between the GitHub repository and the destination namespace in the cluster.

YAML

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ivolve-final-project
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/TheRealQi/CloudDevOpsProject
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: ivolve
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

```

### Configuration Breakdown


| Field             | Value / Path                                | Purpose                                                      |
|------------------|--------------------------------------------|--------------------------------------------------------------|
| Repo URL          | https://github.com/TheRealQi/CloudDevOpsProject | The source of truth for K8s manifests                        |
| Path              | k8s                                         | The specific directory inside the repo containing YAML files |
| Destination Namespace | ivolve                                  | The target namespace where the app will be deployed          |
| Self Heal         | true                                        | Automatically reverts manual changes made to the cluster     |
| Prune             | true                                        | Deletes resources in the cluster that are removed from Git   |
----------

## 2. Deployment Steps

### 2.1 Apply the Application Manifest

Apply the manifest to the cluster to register the application with ArgoCD:

`kubectl apply -f argocd-application.yaml`

### 2.2 Verify Synchronization

Once applied, ArgoCD will begin the "Out of Sync" to "Synced" transition. You can monitor this via the CLI or the Dashboard:

`argocd app get ivolve-final-project`

----------

## 3. GitOps Workflow Summary

1.  **Trigger:** Jenkins updates the image tag in the `/k8s` directory of the repository.
    
2.  **Detection:** ArgoCD polls the repository (or receives a webhook) and notices the manifest version differs from the cluster.
    
3.  **Sync:** ArgoCD applies the `kubectl apply` equivalent to bring the `ivolve` namespace to the state defined in the latest commit.
    
4.  **Reconciliation:** ArgoCD continuously monitors the cluster. If a pod is manually deleted or a configuration is changed via CLI, ArgoCD's **Self-Healing** will automatically revert it to match the Git repository.