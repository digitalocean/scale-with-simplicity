locals {
  # Tags for AWS and DO resources used throughout the configuration
  aws_tags = {
    ReferenceArchitecture : "partner-network-connect-aws"
    Instance : var.name_prefix
  }
  do_tags = [
    "partner-network-connect-aws",
    var.name_prefix
  ]
}

# Generate a secure random BGP password for both red and blue connections
resource "random_password" "bgp_auth_key" {
  length           = 16
  override_special = "!@#.$%^&*+=-_"
}

### DigitalOcean Side ###

# Create a VPC to connect to Megaport from DigitalOcean
resource "digitalocean_vpc" "pnc" {
  name   = var.name_prefix
  region = var.do_region
}

# Lookup the latest Kubernetes version available in the target region
data "digitalocean_kubernetes_versions" "pnc_test" {}

# Lookup the cheapest droplet size with at least 2 vCPUs and 4 GB of RAM
# This will be used to create the DOKS node pool
data "digitalocean_sizes" "main" {
  filter {
    key    = "vcpus"
    values = [2]
  }
  filter {
    key    = "memory"
    values = [4096]
  }
  filter {
    key    = "regions"
    values = [var.do_region]
  }
  sort {
    key       = "price_monthly"
    direction = "asc"
  }
}

# Deploy a DOKS cluster into the VPC with routing agent enabled
# This cluster is used to validate Megaport connectivity
resource "digitalocean_kubernetes_cluster" "pnc_test" {
  name           = var.name_prefix
  region         = var.do_region
  version        = data.digitalocean_kubernetes_versions.pnc_test.latest_version
  vpc_uuid       = digitalocean_vpc.pnc.id
  cluster_subnet = var.doks_cluster_subnet
  service_subnet = var.doks_service_subnet
  tags           = local.do_tags

  routing_agent {
    enabled = true
  }

  node_pool {
    name       = "${var.name_prefix}-nodepool"
    size       = data.digitalocean_sizes.main.sizes[0].slug
    node_count = 1
    tags       = local.do_tags
  }
}

### Megaport Connection ###

provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}

# Global partner interconnect via Megaport
# This module sets up:
#   * A Megaport Cloud Router (MCR) and Virtual Cross Connect (VXC) between DigitalOcean and AWS
#   * BGP peering configuration between the DO and AWS routers (IP addresses, authentication, ASN)
#   * Connectivity to AWS's Virtual Private Gateway (VGW) using your supplied VGW ID
#   * Tagging, diversity zone selection, and support for high availability
#
# See the Partner Network Connect module README:
# https://github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws
module "pnc_red" {
  source                     = "github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws?ref=v1.0.0"
  name_prefix                = var.name_prefix
  do_region                  = substr(var.do_region, 0, 3)  # Use short region code like nyc
  mp_contract_term_months    = var.mp_contract_term_months
  mcr_port_bandwidth_in_mbps = 1000
  vxc_bandwidth_in_mbps      = 1000
  mp_do_location             = var.mp_do_location_red
  mp_aws_location            = var.mp_aws_location_red
  aws_region_full_name       = var.aws_region_full_name
  aws_vgw_id                 = module.aws_vpc.vgw_id
  do_vpc_ids                 = [digitalocean_vpc.pnc.id]
  bgp_password               = random_password.bgp_auth_key.result
  diversity_zone             = "red"
  do_local_router_ip         = "169.254.0.1/29"
  do_peer_router_ip          = "169.254.0.6/29"
}

# Optional High Availability Megaport connection (Blue)
# Creates a redundant Virtual Cross Connect (VXC) in a different Megaport diversity zone.
# This module call is nearly identical to pnc_red but includes a `parent_uuid` to link HA circuits.
# See README:
# https://github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws
module "pnc_blue" {
  count                      = var.ha_enabled ? 1 : 0
  source                     = "github.com/digitalocean/terraform-digitalocean-partner-network-connect-aws?ref=v1.0.0"
  name_prefix                = var.name_prefix
  do_region                  = substr(var.do_region, 0, 3)
  mp_contract_term_months    = var.mp_contract_term_months
  mcr_port_bandwidth_in_mbps = 1000
  vxc_bandwidth_in_mbps      = 1000
  mp_do_location             = var.mp_do_location_blue
  mp_aws_location            = var.mp_aws_location_blue
  aws_region_full_name       = var.aws_region_full_name
  aws_vgw_id                 = module.aws_vpc.vgw_id
  do_vpc_ids                 = [digitalocean_vpc.pnc.id]
  bgp_password               = random_password.bgp_auth_key.result
  diversity_zone             = "blue"
  parent_uuid                = module.pnc_red.partner_attachment_uuid
  do_local_router_ip         = "169.254.0.9/29"
  do_peer_router_ip          = "169.254.0.14/29"
}

### AWS Side ###

provider "aws" {
  region = var.aws_region
}

# Create a VPC in AWS with a VPN Gateway to connect to Megaport
module "aws_vpc" {
  source                             = "terraform-aws-modules/vpc/aws"
  version                            = "~> 5"
  name                               = var.name_prefix
  cidr                               = var.aws_vpc_cidr
  azs                                = ["${var.aws_region}a"]
  private_subnets                    = [var.aws_vpc_cidr]
  enable_vpn_gateway                 = true
  tags                               = local.aws_tags
  propagate_private_route_tables_vgw = true
}

# Lookup latest ARM64 Amazon Linux AMI
# Used to launch a test EC2 instance
data "aws_ami" "amazon_linux_arm" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["137112412989"]
}

# Security group to allow ICMP ping for connectivity testing
resource "aws_security_group" "allow_ping" {
  name        = "${var.name_prefix}-allow-ping"
  description = "Allow ICMP ping from anywhere"
  vpc_id      = module.aws_vpc.vpc_id
  ingress {
    description = "Allow ICMP ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch a test EC2 instance into the AWS VPC
# Used to validate cross-cloud connectivity
resource "aws_instance" "t4g_nano" {
  ami                         = data.aws_ami.amazon_linux_arm.id
  instance_type               = "t4g.nano"
  associate_public_ip_address = false
  subnet_id                   = module.aws_vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_ping.id]
}
