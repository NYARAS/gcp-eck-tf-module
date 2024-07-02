variable "cluster_name" {
  type        = string
  description = "GKE cluster name."
  default = "demo"
}

variable "email" {
  type        = string
  description = "Please, enter your email (elastic email) or a user."
  default = "calvineotieno.com"
}

variable "operator_version" {
  default = "2.12.1"
  description = "The version of the eck to run."
}

variable "node_selector" {
  default = "elk"
  description = "The node selector to use."
}

variable "gcp_project_id" {
  description = "GCP project ID"
  default = "your_example_project"
}

variable "clusterName" {
  default = "demo"
  description = "ECK name"
}

variable "elastic_user_password" {
  default = "ZKzPgIKt3lp5EG8JtuS8KzJFOUM"
  sensitive = true
  description = "ELK user custom password."
}

variable "fqdn" {
  description = "The FQDN to use for Elastic and Kibana. example calvineotieno.com -> kibana.calvineotieno.com."
  default = "calvineotieno.com"
}

variable "HostEmail" {
  default = "calvineotieno.com"
  description = "The email address to use for managing LetsEncypt certs by Cert Manager."
}
