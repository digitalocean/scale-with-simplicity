terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  # Set your DigitalOcean API token using environment variable TF_VAR_do_token
  token             = var.do_token
  # spaces_access_id  = var.spaces_access_id
  # spaces_secret_key = var.spaces_secret_key
} 