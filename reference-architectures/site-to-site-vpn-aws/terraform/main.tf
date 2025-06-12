provider "aws" {
  region = var.aws_region
}

locals {
  aws_tags = {
    ReferenceArchitecture: "site-to-site-vpn-aws"
    Instance: var.name_prefix
  }
  do_tags = [
    "site-to-site-vpn-aws",
    var.name_prefix
  ]
}

resource "digitalocean_vpc" "vpn" {
  name     = var.name_prefix
  region   = var.do_region
  ip_range = var.do_vpc_cidr
}

resource "digitalocean_reserved_ip" "vpn_gateway" {
  region = var.do_region
}

module "aws_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = var.name_prefix
  cidr = var.aws_vpc_cidr
  azs             = ["${var.aws_region}a"]
  private_subnets = [var.aws_vpc_cidr]
  enable_vpn_gateway = true
  tags = local.aws_tags
}

resource "aws_customer_gateway" "gateway" {
  # device_name = local.vgw_droplet_name
  bgp_asn    = 65000
  ip_address = digitalocean_reserved_ip.vpn_gateway.ip_address
  type       = "ipsec.1"
  tags = local.aws_tags
}

module "vpn_gateway" {
  source  = "terraform-aws-modules/vpn-gateway/aws"
  version = "~> 3.7.2"
  vpc_id = module.aws_vpc.vpc_id
  vpn_gateway_id = module.aws_vpc.vgw_id
  create_vpn_gateway_attachment = false
  customer_gateway_id          = aws_customer_gateway.gateway.id
  vpc_subnet_route_table_ids = module.aws_vpc.private_route_table_ids
  vpc_subnet_route_table_count =  length(module.aws_vpc.private_route_table_ids)
  vpn_connection_static_routes_only         = true
  vpn_connection_static_routes_destinations = [var.do_vpc_cidr]
  tunnel1_inside_cidr = "169.254.104.100/30"
  tunnel1_preshared_key = var.vpn_psk
  # Even through we are using a single tunnel this TF module from AWS doesn't work quite right unless we specify tunnel2 items
  tunnel2_inside_cidr = "169.254.104.104/30"
  tunnel2_preshared_key = var.vpn_psk
  tags = local.aws_tags
}

module "do_vpn_droplet" {
  source = "../../../../terraform-digitalocean-ipsec-gateway"
  image         = var.droplet_image
  name          = "${var.name_prefix}-vgw"
  region        = var.do_region
  remote_vpn_ip = module.vpn_gateway.vpn_connection_tunnel1_address
  reserved_ip   = digitalocean_reserved_ip.vpn_gateway.ip_address
  size          = var.droplet_size
  vpc_id        = digitalocean_vpc.vpn.id
  vpn_psk       = var.vpn_psk
  ssh_keys = [46093502]
  tags = local.do_tags
}
