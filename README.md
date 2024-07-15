# GCP Terraform Module for Elastic Cloud on Kubernetes

This Terraform module is designed to be used for creating a Elastic Cloud on Kubernetes. This is a usecase where you want to run your own Elastic Cloud on Kubernetes with minimal resources and having full control of your cluster.

This module creates ECK with basic license hence some features are not available like webhooks in connectors. See this for full details on [ECK Licensing](https://www.elastic.co/subscriptions)


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.4 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.25.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.25.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10.1 |


## Install Instructions

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install?product_intent=terraform) is installed on your local machine.
- A working [GCP Account](https://cloud.google.com/free?hl=en). You can sign up for a [free tier](https://cloud.google.com/free?hl=en).
- Optional - A Public Hosted Domain in Google Cloud DNS/Any DNS Provider of your choice.

### Update the Terraform Variables

- Edit `backend.tf ` file.

    Update the bucket name with yours.
- Update `terraform.tfvars.example` file to `terraform.tfvars`. ⚠️ _DO NOT COMMIT THIS FILE_.

    Replace all the default values defined in `variables.tf` with your own values.

### Init and Apply

- Initialize Terraform:

    ```sh
    terraform init
    ```

- Create a Terraform plan

    ```sh
    terraform plan  -out eckplan.out
    ```

- Apply the plan

    ```sh
    terraform apply "eckplan.out"
    ```

### Destroy the infrastructure

When you are done with everything and you want to cleanup and destroy your infrastructure, you run Terradorm Destroy:


```sh
 terraform destroy -auto-approve
 ```

## Authors and Maintainers

* Calvine Otieno /[Calvine Otieno](https://github.com/NYARAS)
