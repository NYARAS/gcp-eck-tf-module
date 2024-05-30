resource "helm_release" "calert" {
  name       = "calert"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  repository = "https://mr-karan.github.io/calert/charts"
  wait       = true
  chart      = "calert"
  version    = "v2.1.1"
   values = [
    <<EOF
    providers:
        prod_alerts:
          type: "google_chat"
          endpoint: "REDACTED"
          max_idle_conns:  50
          timeout: "30s"
          template: "static/message.tmpl"
          thread_ttl: "12h"
          dry_run: false
        dev_alerts:
          type: "google_chat"
          endpoint: "<REDACTED>"
          max_idle_conns:  50
          timeout: "30s"
          template: "static/message.tmpl"
          thread_ttl: "12h"
          dry_run: true
    templates:
        message.tmpl: |
            *({{.Labels.severity | toUpper }}) {{ .Labels.alertname | Title }} - {{.Status | Title }}*
            {{ range .Annotations.SortedPairs -}}
            {{ .Name | Title }}: {{ .Value}}
            {{ end -}}

        dev_alerts.tmpl: |
            *({{.Labels.severity | toUpper }}) {{ .Labels.alertname | Title }} - {{.Status | Title }}*
            {{ range .Annotations.SortedPairs -}}
            {{ .Name | Title }}: {{ .Value}}
            {{ end -}}
EOF
  ]
}
