locals {
  region = "europe-west4"
}

variable "kubernetes_name" {
  type        = string
  description  = "GKE cluster name."
}

variable "email" {
  type        = string
  description = "Please, enter your email (elastic email) or a user."
}

variable "operator_version" {
  default = "2.12.1"
}

variable "node_selector" {
  default = "elk"
}

variable "gcp_project_id" {
  
}

variable "clusterName" {
  default = "demo"
}

variable "elastic_user_password" {
}

variable "kibana_url" {
  
}
