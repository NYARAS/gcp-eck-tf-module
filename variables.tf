locals {
  region = "europe-west4"
}

variable "kubernetes_name" {
  type        = string
  description  = "Please, enter your GKE cluster name"
}
