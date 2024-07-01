module "nsw_elastic_managed" {
  source = "./eck"
  email = var.email
  HostEmail = var.HostEmail
  gcp_project_id = var.gcp_project_id
  clusterName = var.clusterName
  kubernetes_name = var.kubernetes_name
  host = var.host
  elastic_user_password = var.elastic_user_password
}
