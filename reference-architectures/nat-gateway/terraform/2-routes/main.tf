terraform {
  required_version = ">= 1.6.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }
}

provider "digitalocean" {}

data "digitalocean_kubernetes_cluster" "this" {
  id = var.cluster_id
}

provider "kubernetes" {
  host                   = data.digitalocean_kubernetes_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  token                  = data.digitalocean_kubernetes_cluster.this.kube_config[0].token
}

resource "kubernetes_manifest" "default_egress_via_nat" {
  manifest = {
    apiVersion = "networking.doks.digitalocean.com/v1alpha1"
    kind       = "Route"
    metadata   = { name = "default-egress-via-nat" }
    spec = {
      destinations = ["0.0.0.0/0"]
      gateways     = [var.nat_gateway_gateway_ip]
    }
  }
}
