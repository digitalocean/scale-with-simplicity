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
  propagate_private_route_tables_vgw = true
}

data "aws_ami" "amazon_linux_arm" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"] # Amazon Linux 2 ARM64
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["137112412989"] # Amazon
}

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

resource "aws_instance" "t4g_nano" {
  ami           = data.aws_ami.amazon_linux_arm.id
  instance_type = "t4g.nano"
  subnet_id                   = module.aws_vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_ping.id]
  tags = local.aws_tags
}

resource "aws_customer_gateway" "gateway" {
  # device_name = "${var.name_prefix}-vgw"
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
  remote_vpn_cidr = module.aws_vpc.vpc_cidr_block
  reserved_ip   = digitalocean_reserved_ip.vpn_gateway.ip_address
  size          = var.droplet_size
  vpc_id        = digitalocean_vpc.vpn.id
  vpn_psk       = var.vpn_psk
  ssh_keys = [46093502]
  tags = local.do_tags
}
