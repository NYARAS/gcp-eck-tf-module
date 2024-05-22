resource "kubernetes_namespace" "cert-manager" {
  metadata {
    labels = {
      "certmanager.k8s.io/disable-validation" = "true"
      "cluster" = var.clusterName
    }
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager-h3"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  wait       = true
  values = [
    <<EOF
nodeSelector: {}
#   purpose: general-services
installCRDs: true
  EOF
  ]
}

resource "kubectl_manifest" "cluster-issuer" {
  depends_on = [helm_release.cert-manager]
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.HostEmail}
    privateKeySecretRef:
      name: letsencrypt-key
    solvers:
    - http01:
        ingress:
          class: nginx
YAML
}

resource "kubectl_manifest" "cluster-issuer-staging" {
  depends_on = [helm_release.cert-manager]
  yaml_body  = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${var.HostEmail}
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: nginx
YAML
}
