terraform {
  required_version = ">= 0.15.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.0.2"
    }
    google = {
      source  = "hashicorp/google"
      version = "4.1.0"
    }
  }
}
