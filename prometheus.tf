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
  enabled: true
  config:
    # enabled: true
    global:
      resolve_timeout: 1m
      slack_api_url: '<SLACK_URL>'
    templates:
      - '/etc/alertmanager/*.tmpl'

    receivers:
    - name: 'prometheus'
      slack_configs:
      - channel: '#prometheus'
        send_resolved: true
        icon_url: https://avatars3.githubusercontent.com/u/3380462
        title: |-
          [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }} for {{ .CommonLabels.job }}
          {{- if gt (len .CommonLabels) (len .GroupLabels) -}}
            {{" "}}(
            {{- with .CommonLabels.Remove .GroupLabels.Names }}
              {{- range $index, $label := .SortedPairs -}}
                {{ if $index }}, {{ end }}
                {{- $label.Name }}="{{ $label.Value -}}"
              {{- end }}
            {{- end -}}
            )
          {{- end }}
        text: >-
          {{ range .Alerts -}}
          *Alert:* {{ .Annotations.title }}{{ if .Labels.severity }} - `{{ .Labels.severity }}`{{ end }}
          *Description:* {{ .Annotations.description }}
          *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}

    route:
      receiver: 'prometheus'

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
        - job_name: kubernetes-apiservers
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: https
          kubernetes_sd_configs:
          - role: endpoints
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            separator: ;
            regex: default;kubernetes;https
            replacement: $1
            action: keep
        - job_name: kubernetes-nodes
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: https
          kubernetes_sd_configs:
          - role: node
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          relabel_configs:
          - separator: ;
            regex: __meta_kubernetes_node_label_(.+)
            replacement: $1
            action: labelmap
          - separator: ;
            regex: (.*)
            target_label: __address__
            replacement: kubernetes.default.svc:443
            action: replace
          - source_labels: [__meta_kubernetes_node_name]
            separator: ;
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics
            action: replace
        - job_name: kubernetes-nodes-cadvisor
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: https
          kubernetes_sd_configs:
          - role: node
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: true
          relabel_configs:
          - separator: ;
            regex: __meta_kubernetes_node_label_(.+)
            replacement: $1
            action: labelmap
          - separator: ;
            regex: (.*)
            target_label: __address__
            replacement: kubernetes.default.svc:443
            action: replace
          - source_labels: [__meta_kubernetes_node_name]
            separator: ;
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
            action: replace
        - job_name: kubernetes-service-endpoints
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: http
          kubernetes_sd_configs:
          - role: endpoints
          relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            separator: ;
            regex: "true"
            replacement: $1
            action: keep
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            separator: ;
            regex: (https?)
            target_label: __scheme__
            replacement: $1
            action: replace
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            separator: ;
            regex: (.+)
            target_label: __metrics_path__
            replacement: $1
            action: replace
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            separator: ;
            regex: ([^:]+)(?::\d+)?;(\d+)
            target_label: __address__
            replacement: $1:$2
            action: replace
          - separator: ;
            regex: __meta_kubernetes_service_label_(.+)
            replacement: $1
            action: labelmap
          - source_labels: [__meta_kubernetes_namespace]
            separator: ;
            regex: (.*)
            target_label: kubernetes_namespace
            replacement: $1
            action: replace
          - source_labels: [__meta_kubernetes_service_name]
            separator: ;
            regex: (.*)
            target_label: kubernetes_name
            replacement: $1
            action: replace
          - source_labels: [__meta_kubernetes_pod_node_name]
            separator: ;
            regex: (.*)
            target_label: kubernetes_node
            replacement: $1
            action: replace
        - job_name: prometheus-pushgateway
          honor_labels: true
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: http
          kubernetes_sd_configs:
          - role: service
          relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
            separator: ;
            regex: pushgateway
            replacement: $1
            action: keep
        - job_name: kubernetes-services
          params:
            module:
            - http_2xx
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /probe
          scheme: http
          kubernetes_sd_configs:
          - role: service
          relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
            separator: ;
            regex: "true"
            replacement: $1
            action: keep
          - source_labels: [__address__]
            separator: ;
            regex: (.*)
            target_label: __param_target
            replacement: $1
            action: replace
          - separator: ;
            regex: (.*)
            target_label: __address__
            replacement: blackbox
            action: replace
          - source_labels: [__param_target]
            separator: ;
            regex: (.*)
            target_label: instance
            replacement: $1
            action: replace
          - separator: ;
            regex: __meta_kubernetes_service_label_(.+)
            replacement: $1
            action: labelmap
          - source_labels: [__meta_kubernetes_namespace]
            separator: ;
            regex: (.*)
            target_label: kubernetes_namespace
            replacement: $1
            action: replace
          - source_labels: [__meta_kubernetes_service_name]
            separator: ;
            regex: (.*)
            target_label: kubernetes_name
            replacement: $1
            action: replace
        - job_name: kubernetes-pods
          scrape_interval: 1m
          scrape_timeout: 10s
          metrics_path: /metrics
          scheme: http
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            separator: ;
            regex: "true"
            replacement: $1
            action: keep
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            separator: ;
            regex: (.+)
            target_label: __metrics_path__
            replacement: $1
            action: replace
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            separator: ;
            regex: ([^:]+)(?::\d+)?;(\d+)
            target_label: __address__
            replacement: $1:$2
            action: replace
          - separator: ;
            regex: __meta_kubernetes_pod_label_(.+)
            replacement: $1
            action: labelmap
          - source_labels: [__meta_kubernetes_namespace]
            separator: ;
            regex: (.*)
            target_label: kubernetes_namespace
            replacement: $1
            action: replace
          - source_labels: [__meta_kubernetes_pod_name]
            separator: ;
            regex: (.*)
            target_label: kubernetes_pod_name
            replacement: $1
            action: replace
  rules:
    groups:
      - name: Deployment
        rules:
        - alert: Deployment at 0 Replicas
          annotations:
            summary: Deployment {{$labels.deployment}} in {{$labels.namespace}} is currently having no pods running
          expr: |
            sum(kube_deployment_status_replicas{pod_template_hash=""}) by (deployment,namespace)  < 1
          for: 1m
          labels:
            team: devops
            severity: "critical"
        - alert: HPA Scaling Limited  
          annotations: 
            summary: HPA named {{$labels.hpa}} in {{$labels.namespace}} namespace has reached scaling limited state
          expr: | 
            (sum(kube_hpa_status_condition{condition="ScalingLimited",status="true"}) by (hpa,namespace)) == 1
          for: 1m
          labels: 
            team: devops
            severity: "critical"
        - alert: HPA at MaxCapacity 
          annotations: 
            summary: HPA named {{$labels.hpa}} in {{$labels.namespace}} namespace is running at Max Capacity
          expr: | 
            ((sum(kube_hpa_spec_max_replicas) by (hpa,namespace)) - (sum(kube_hpa_status_current_replicas) by (hpa,namespace))) == 0
          for: 1m
          labels: 
            team: devops
            severity: "critical"
EOF
  ]
}
