provider "aws" {
  region = var.aws_region
}

# Tag definitions for use on AWS and DigitalOcean resources
locals {
  aws_tags = {
    ReferenceArchitecture : "site-to-site-vpn-aws"
    Instance : var.name_prefix
  }
  do_tags = [
    "site-to-site-vpn-aws",
    var.name_prefix
  ]
}

####
# DigitalOcean Side
####

# Create a VPC on DigitalOcean for VPN resources
resource "digitalocean_vpc" "vpn" {
  name     = var.name_prefix
  region   = var.do_region
  ip_range = var.do_vpc_cidr
}

# Reserve a static public IP on DO to assign to the VPN droplet
resource "digitalocean_reserved_ip" "vpn_gateway" {
  region = var.do_region
}

# Launch a VPN gateway droplet and configure IPsec
# This uses the terraform-digitalocean-ipsec-gateway module:
# https://github.com/digitalocean/terraform-digitalocean-ipsec-gateway
module "do_vpn_droplet" {
  source               = "github.com/digitalocean/terraform-digitalocean-ipsec-gateway?ref=v1.1.0"
  name                 = "${var.name_prefix}-vgw"
  size                 = var.droplet_size
  region               = var.do_region
  vpc_id               = digitalocean_vpc.vpn.id
  ssh_keys             = var.droplet_ssh_keys
  tags                 = local.do_tags
  do_vpn_public_ip     = digitalocean_reserved_ip.vpn_gateway.ip_address
  do_vpn_tunnel_ip     = module.vpn_gateway.vpn_connection_tunnel1_cgw_inside_address
  remote_vpn_public_ip = module.vpn_gateway.vpn_connection_tunnel1_address
  remote_vpn_tunnel_ip = module.vpn_gateway.vpn_connection_tunnel1_vgw_inside_address
  remote_vpn_cidr      = module.aws_vpc.vpc_cidr_block
  vpn_psk              = var.vpn_psk
}

# Lookup the latest DigitalOcean Kubernetes versions
# Used for creating the test DOKS cluster
data "digitalocean_kubernetes_versions" "vpn_test" {}

# Pick the cheapest droplet size with at least 2 vCPUs and 4 GB RAM in the selected region
# Used for DOKS node pool size
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

# Launch a test DOKS cluster in the DO VPC to test cross-cloud VPN connectivity
resource "digitalocean_kubernetes_cluster" "vpn_test" {
  name           = var.name_prefix
  region         = var.do_region
  version        = data.digitalocean_kubernetes_versions.vpn_test.latest_version
  cluster_subnet = var.doks_cluster_subnet
  service_subnet = var.doks_service_subnet
  vpc_uuid       = digitalocean_vpc.vpn.id
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

####
# AWS Side
####

# Create a VPC in AWS with private subnets and attach a VPN gateway
# Uses the terraform-aws-modules/vpc module:
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "aws_vpc" {
  source                             = "terraform-aws-modules/vpc/aws"
  version                            = "~> 5.21"
  name                               = var.name_prefix
  cidr                               = var.aws_vpc_cidr
  azs                                = ["${var.aws_region}a"]
  private_subnets                    = [var.aws_vpc_cidr]
  enable_vpn_gateway                 = true
  tags                               = local.aws_tags
  propagate_private_route_tables_vgw = true
}

# Lookup latest Amazon Linux ARM64 image
# Used for testing the VPN from an AWS instance
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

# Allow ICMP ping for connectivity testing
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
  tags = local.aws_tags
}

# Launch a tiny ARM instance in the AWS VPC to test VPN reachability
resource "aws_instance" "t4g_nano" {
  ami                         = data.aws_ami.amazon_linux_arm.id
  instance_type               = "t4g.nano"
  associate_public_ip_address = false
  subnet_id                   = module.aws_vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_ping.id]
  tags                        = local.aws_tags
}

# Create a Customer Gateway in AWS pointing to the DO VPN public IP
resource "aws_customer_gateway" "gateway" {
  device_name = "${var.name_prefix}-vgw"
  bgp_asn     = 65000
  ip_address  = digitalocean_reserved_ip.vpn_gateway.ip_address
  type        = "ipsec.1"
  tags        = local.aws_tags
}

# Create the VPN connection from AWS to the DO VPN gateway
# Uses the terraform-aws-modules/vpn-gateway module:
# https://registry.terraform.io/modules/terraform-aws-modules/vpn-gateway/aws/latest
module "vpn_gateway" {
  source                                    = "terraform-aws-modules/vpn-gateway/aws"
  version                                   = "~> 3.7"
  vpc_id                                    = module.aws_vpc.vpc_id
  vpn_gateway_id                            = module.aws_vpc.vgw_id
  create_vpn_gateway_attachment             = false
  customer_gateway_id                       = aws_customer_gateway.gateway.id
  vpc_subnet_route_table_ids                = module.aws_vpc.private_route_table_ids
  vpc_subnet_route_table_count              = length(module.aws_vpc.private_route_table_ids)
  vpn_connection_static_routes_only         = true
  vpn_connection_static_routes_destinations = [var.do_vpc_cidr]
  tunnel1_inside_cidr                       = "169.254.104.100/30"
  tunnel1_preshared_key                     = var.vpn_psk
  tunnel2_inside_cidr                       = "169.254.104.104/30"
  tunnel2_preshared_key                     = var.vpn_psk
  tags                                      = local.aws_tags
}

# Route DOKS cluster subnet into the VPN connection so AWS can reach DO workloads
resource "aws_vpn_connection_route" "doks_route" {
  destination_cidr_block = digitalocean_kubernetes_cluster.vpn_test.cluster_subnet
  vpn_connection_id      = module.vpn_gateway.vpn_connection_id
}
