terraform {
  required_version = "~> 1.0"

  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
      }
    }
}

provider "digitalocean"{
  token = var.do_token
}

# Resource 1: VPC
resource "digitalocean_vpc" "ra-nat-gateway-vpc" {
  name = "ra-nat-gateway-vpc"
  region = var.region
  ip_range = "192.168.44.0/24"
}

# Resource 2: NAT Gateway
resource "digitalocean_vpc_nat_gateway" "this" {
  name = var.nat_gateway_name
  type = "PUBLIC"
  region = var.region
  size = 1
  vpcs {
    vpc_uuid = digitalocean_vpc.ra-nat-gateway-vpc.id
  }
}

# Resource 3: Droplet(non K8 host)
resource "digitalocean_droplet" "non-k8-host-droplet" {
  image = "fedora-42-x64" 
  size = "s-1vcpu-512mb-10gb"
  name = "non-k8-host-droplet"
  vpc_uuid = digitalocean_vpc.ra-nat-gateway-vpc.id
  user_data = templatefile("${path.module}/cloud-init-fedora.yaml", {
    nat_gateway_ip = [for vpc in digitalocean_vpc_nat_gateway.this.vpcs : vpc.gateway_ip][0]
  })
  depends_on = [digitalocean_vpc_nat_gateway.this]
}

# Resource 4: K8 cluster
resource "digitalocean_kubernetes_cluster" "k8-cluster" {
  name = "foo"
  region = var.region
  version = "latest"
  node_pool {
    name = "worker-pool"
    size = "s-2vcpu-2gb"
    node_count = 2
  }
}
