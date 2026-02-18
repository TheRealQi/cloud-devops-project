# Phase 3: Kubernetes Manifests
In this phase, Kubernetes manifests are created to deploy the Flask app on a Kubernetes cluster.
## 1. Namespace
The namespace `ivolve` is defined to logically separate the resources for this application.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ivolve
```

## 2. App Deployment
The Flask app is deployed with 4 replicas for high availability. The deployment defines resource requests and limits for CPU and memory, ensuring efficient resource utilization.
### 2.1 Dockerfile Definition

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: ivolve
spec:
  replicas: 4
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
        - name: flask-app
          image: 225823723481.dkr.ecr.us-east-1.amazonaws.com/finalprojectapp:1
          resources:
            requests:
              cpu: "100m"
              memory: "200Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
          ports:
            - containerPort: 5000
```

## 3. Service
The service `ivolve-app-service` is set up as a `ClusterIP`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ivolve-app-service
  namespace: ivolve
spec:
  type: ClusterIP
  selector:
    app: flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
```

## 4. Ingress
The Ingress resource is defined to route traffic to the Flask app. It uses the Nginx ingress controller.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ivolve-app-service
  namespace: ivolve
spec:
  type: ClusterIP
  selector:
    app: flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
```
4. Kubernetes Setup with Terraform on EKS (Phase 4)

The Kubernetes cluster and the setup is handled in Phase 4 using Terraform to provision on AWS EKS.

