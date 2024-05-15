# provider "helm" {
#   kubernetes {
#     host                   = "https://${google_container_cluster._.endpoint}"
# #    config_path    = "~/.kube/config"

#     client_certificate     = base64decode(google_container_cluster._.master_auth.0.client_certificate)
#     client_key             = base64decode(google_container_cluster._.master_auth.0.client_key)
#     cluster_ca_certificate = base64decode(google_container_cluster._.master_auth.0.cluster_ca_certificate)
#   }
# }

data "google_client_config" "default" {
}
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster._.endpoint}/"
    cluster_ca_certificate = base64decode(google_container_cluster._.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
    #    client_key             = module.prodk8s.cluster_key
    #    client_certificate     = module.prodk8s.cluster_client_cert
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster._.endpoint}/"
  cluster_ca_certificate = base64decode(google_container_cluster._.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  #  client_key             = module.prodk8s.cluster_key
  #  client_certificate     = module.prodk8s.cluster_client_cert
}

provider "kubectl" {
  host                   = google_container_cluster._.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster._.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}


provider "google" {
  project = "ace-resolver-422807-t7"
  region  = "europe-west4"
  zone    = "europe-west4-b"
}
