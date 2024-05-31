resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

output "prometheus_namespace" {
  value = kubernetes_namespace.prometheus.metadata.0.name
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  wait       = true
  chart      = "prometheus"
  version    = "23.1.0"
  values = [
    <<EOF
server:
  retention: "7d"
  image:
    repository: quay.io/prometheus/prometheus
    tag: "v2.45.0"
  global:
    scrape_interval: "2m"
    scrape_timeout: "30s"
    evaluation_interval: "2m"
  # nodeSelector:
  #   purpose: general-services
  persistentVolume:
    size: 50Gi
  resources:
    limits:
      cpu: 500m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 2Gi
alertmanager:
  enabled: false
pushgateway:
  enabled: false
prometheus:
  prometheusSpec:
    containers: 
      - name: prometheus-server
        startupProbe:
          failureThreshold: 300
    scrapeInterval: "120s"
    scrapeTimeout: "120s"
kubeStateMetrics:
  enabled: true
  releaseLabel: true
  prometheus:
    monitor:
      enabled: true
nodeExporter:
  enabled: true
kube-state-metrics:
  image:
    registry: registry.k8s.io
    repository: kube-state-metrics/kube-state-metrics
    tag: "v2.9.2"

extraScrapeConfigs: |
  - job_name: 'kubernetes-cadvisor'
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
    - role: node
    relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: kubernetes.default.svc:443
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/$${1}/proxy/metrics/cadvisor

serverFiles:
  alerting_rules.yml: {}

  prometheus.yml:
      rule_files:
        - /etc/config/recording_rules.yml
        - /etc/config/alerting_rules.yml
        - /etc/config/rules
        - /etc/config/alerts

      scrape_configs:
        - job_name: prometheus
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: http
          static_configs:
          - targets:
            - localhost:9090
EOF
  ]
}
