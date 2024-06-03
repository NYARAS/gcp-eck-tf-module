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
  cluster            = google_container_cluster.demo_cluster.id
  initial_node_count = 1

  autoscaling {
    min_node_count = 3
    max_node_count = 4
  }

  node_config {
    preemptible  = false
    machine_type = "e2-standard-4"
  }
}

resource "kubernetes_namespace" "elastic" {
  metadata {
    name = "elastic"
  }
}
# Bucket to use as Elastic Snapshots storage
resource "google_storage_bucket" "demo_elastic_snapshots" {
  project       = var.gcp_project_id
  name          = "demo-eck-snapshots"
  location      = "EUROPE-WEST4"
  force_destroy = true
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
  labels = {
    "bucket-name" = "demo-eck-snapshots"
  }
}

resource "google_service_account" "demo_elastic_snapshots" {
  account_id   = "demo-elastic-snapshots"
  display_name = "Elastic SA for snapshots."
  description  = "Google Service Account used for My Service."
}

locals {
  gke_service_account_name = "demo-elastic-snapshots"
}

resource "google_storage_bucket_iam_binding" "demo_elastic_snapshots" {
  bucket = google_storage_bucket.demo_elastic_snapshots.name
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${google_service_account.demo_elastic_snapshots.email}",
  ]
}

resource "google_service_account_key" "demo_elastic_snapshots" {
  service_account_id = google_service_account.demo_elastic_snapshots.name
  public_key_type    = "TYPE_X509_PEM_FILE"
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

resource "kubernetes_service_account" "demo_elastic_snapshots" {
  metadata {
    name      = local.gke_service_account_name
    namespace = kubernetes_namespace.elastic.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.demo_elastic_snapshots.email,

    }
  }
  automount_service_account_token = false
}

# Allow the Kubernetes service account to impersonate the IAM service account
resource "google_service_account_iam_binding" "demo_elastic_snapshots" {
  service_account_id = google_service_account.demo_elastic_snapshots.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${kubernetes_namespace.elastic.metadata[0].name}/${local.gke_service_account_name}]"
  ]
}

resource "helm_release" "elastic" {
  name = "elastic-operator"

  repository       = "https://helm.elastic.co"
  chart            = "eck-operator"
  version          = var.operator_version
  namespace        = "elastic-system"
  create_namespace = "true"

  depends_on = [google_container_cluster.demo_cluster, google_container_node_pool.node-pool]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [helm_release.elastic]

  create_duration = "30s"
}

resource "kubernetes_secret" "demo_elastic_es_user_creds" {
  metadata {
    name      = "${var.clusterName}-es-elastic-user"
    namespace = kubernetes_namespace.elastic.metadata[0].name

    labels = {
      "name" = "${var.clusterName}-es-elastic-user"
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].labels
    ]
  }
  type = "opaque"
  data = {
    elastic = var.elastic_user_password
  }
}

resource "kubectl_manifest" "demo_elastic" {
  yaml_body = <<YAML
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: ${var.clusterName}
  namespace: ${kubernetes_namespace.elastic.metadata[0].name}
spec:
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  version: 8.1.3
  # secureSettings:
  # - secretName: gcs-credentials
  nodeSets:
  - name: ${var.clusterName}
    count: 3
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        nodeSelector: {}
        automountServiceAccountToken: true
        serviceAccountName: ${local.gke_service_account_name}
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
  depends_on = [helm_release.elastic, time_sleep.wait_30_seconds, kubernetes_secret.demo_elastic_es_user_creds, kubernetes_namespace.elastic]
}

resource "kubectl_manifest" "demo_kibana" {
  yaml_body = <<YAML
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: ${var.clusterName}
  namespace: ${kubernetes_namespace.elastic.metadata[0].name}
spec:
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  version: 8.1.3
  count: 1
  config:
    server.publicBaseUrl: "https://kibana.${var.host}"
  elasticsearchRef:
    name: ${var.clusterName}
  podTemplate:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        resources:
          limits:
            memory: 2Gi
            cpu: 1
YAML

  provisioner "local-exec" {
    command = "sleep 60"
  }
  depends_on = [helm_release.elastic, kubectl_manifest.demo_elastic]
}


resource "kubernetes_cron_job_v1" "demo_elastic_backup" {
  metadata {
    name      = var.clusterName
    namespace = kubernetes_namespace.elastic.metadata[0].name
  }
  spec {
    concurrency_policy            = "Replace"
    failed_jobs_history_limit     = var.backup_failed_jobs_history_limit
    schedule                      = var.backup_schedule
    successful_jobs_history_limit = var.backup_successful_jobs_history_limit
    job_template {
      metadata {}
      spec {
        backoff_limit              = 2
        ttl_seconds_after_finished = 10
        template {
          metadata {}
          spec {
            volume {
              name = "es-basic-auth"
              secret {
                secret_name = "${var.clusterName}-es-elastic-user"
              }

            }
            container {
              name  = "elasticsearch-backup-cleanup"
              image = "centos:7"
              command = [
                "/bin/sh",
                "-c",
                "curl -s -i -k -u ${"elastic"}:${var.elastic_user_password} -XPUT ${"http://${var.clusterName}-es-http.elastic.svc.cluster.local:9200/_snapshot/demo-eck-snapshots/%3Csnapshot-%7Bnow%2Fd%7D%3E"}"
              ]

              volume_mount {
                name       = "es-basic-auth"
                mount_path = "/mnt/elastic/es-basic-auth"
              }
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  default     = "*/1 * * * *"
  type        = string
}

variable "backup_failed_jobs_history_limit" {
  description = "Set retention for failed jobs history"
  default     = 5
  type        = number
}

variable "backup_successful_jobs_history_limit" {
  description = "Set retention for successful jobs history"
  default     = 3
  type        = number
}
