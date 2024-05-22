resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  namespace  = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.7.0"
  wait       = true
  timeout    = 1800
  values = [
    <<YAML
nameOverride: nginx-ingress
fullnameOverride: nginx-ingress
rbac:
  create: true
controller:
  publishService:
    enabled: true
  replicaCount: 12
  autoscaling:
    enabled: true
    minReplicas: 12
    maxReplicas: 24
    targetMemoryUtilizationPercentage: null
    targetCPUUtilizationPercentage: 50
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"
  livenessProbe:
    failureThreshold: 3
    initialDelaySeconds: 10
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 1
    httpGet:
      port: 10254
  readinessProbe:
    failureThreshold: 3
    initialDelaySeconds: 10
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 1
    httpGet:
      port: 10254
  nodeSelector: {}
    # purpose: general-services
  config:
    error-log-level: "warn"
    http-snippet: |
      map $status $loggable {
        ~^[23]  0;
        default 1;
      }
  resources:
    requests:
      cpu: 50m
      memory: 150Mi
defaultBackend:
  enabled: true
YAML
  ]
}

