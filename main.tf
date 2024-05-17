resource "google_container_cluster" "demo_cluster" {
  name     = var.kubernetes_name
  location = local.region

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }


  node_pool {
    name = "builtin"
  }
  lifecycle {
    ignore_changes = [node_pool]
  }
}

# Creating and attaching the node-pool to the Kubernetes Cluster
resource "google_container_node_pool" "node-pool" {
  name               = "node-pool"
  cluster            = google_container_cluster._.id
  initial_node_count = 1

  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"
  }
}


resource "helm_release" "elastic" {
  name = "elastic-operator"

  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  version = var.operator_version
  namespace        = "elastic-system"
  create_namespace = "true"

  depends_on = [google_container_cluster._, google_container_node_pool.node-pool]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [helm_release.elastic]

  create_duration = "30s"
}

resource "kubectl_manifest" "demo_elastic" {
    yaml_body = <<YAML
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: demo
spec:
  http:
    service:
     spec:
      ports:
      - name: http # change to use https
        nodePort: 30300
        port: 9200
        protocol: TCP
        targetPort: 9200
      type: NodePort  
    tls:
      selfSignedCertificate:
        disabled: true # change to use https
  version: 8.1.3
  # secureSettings:
  # - secretName: gcs-credentials
  nodeSets:
  - name: demo
    count: 3
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        nodeSelector: {}
        automountServiceAccountToken: true
        serviceAccountName: demo-elastic-snapshots // # change to use created SA
        containers:
        - name: elasticsearch
          env:
          - name: READINESS_PROBE_TIMEOUT
            value: "10"
          resources:
            requests:
              memory: 4Gi
            limits:
              memory: 5Gi
          readinessProbe:
            exec:
              command:
              - bash
              - -c
              - /mnt/elastic-internal/scripts/readiness-probe-script.sh
            failureThreshold: 3
            initialDelaySeconds: 10
            periodSeconds: 12
            successThreshold: 1
            timeoutSeconds: 12
YAML

  provisioner "local-exec" {
     command = "sleep 60"
  }
  depends_on = [helm_release.elastic, time_sleep.wait_30_seconds]
}

resource "kubectl_manifest" "demo_kibana" {
    yaml_body = <<YAML
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: demo
spec:
  http:
    service:
     spec:
      ports:
      - name: http # change to use https
        port: 5601
        protocol: TCP
        targetPort: 5601
      type: NodePort  
    tls:
      selfSignedCertificate:
        disabled: true # change to use https
  version: 8.1.3
  count: 1
  elasticsearchRef:
    name: demo
  podTemplate:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        resources:
          limits:
            memory: 1Gi
            cpu: 1
YAML

  provisioner "local-exec" {
     command = "sleep 60"
  }
  depends_on = [helm_release.elastic, kubectl_manifest.demo_elastic]
}

