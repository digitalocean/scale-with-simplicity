terraform {
  required_version = "~> 1"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.72.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
  }
}

# Read outputs from Stack 1 (1-infra)
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "../1-infra/terraform.tfstate"
  }
}

# Reference the DOKS cluster created in Stack 1
data "digitalocean_kubernetes_cluster" "vllm" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# Configure Kubernetes provider using cluster credentials
provider "kubernetes" {
  host  = data.digitalocean_kubernetes_cluster.vllm.endpoint
  token = data.digitalocean_kubernetes_cluster.vllm.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.vllm.kube_config[0].cluster_ca_certificate
  )
}
