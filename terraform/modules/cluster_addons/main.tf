resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 600
  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "classic"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
      value = "true"
    },
    {
      name  = "controller.metrics.enabled"
      value = "true"
    },
    {
      name  = "controller.podAnnotations.prometheus\\.io/scrape"
      value = "true"
    },
    {
      name  = "controller.podAnnotations.prometheus\\.io/port"
      value = "10254"
    }
  ]
}

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
