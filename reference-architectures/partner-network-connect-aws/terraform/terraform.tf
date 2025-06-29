terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.57"
    }
    megaport = {
      source  = "megaport/megaport"
      version = "~> 1.3.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }

}
