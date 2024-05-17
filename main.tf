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

