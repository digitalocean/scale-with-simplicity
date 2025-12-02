terraform {
  required_version = "~> 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  # token should be set via DIGITALOCEAN_TOKEN or DIGITALOCEAN_ACCESS_TOKEN environment variable
}
