terraform {
  required_version = "~> 1"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }
  }
}
