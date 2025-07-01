locals {
  aws_tags = {
    ReferenceArchitecture : "partner-network-connect-aws"
    Instance : var.name_prefix
  }
  do_tags = [
    "partner-network-connect-aws",
    var.name_prefix
  ]
}

resource "random_password" "bgp_auth_key" {
  length           = 16
  override_special = "!@#.$%^&*+=-_"
}

### DO

resource "digitalocean_vpc" "pnc" {
  name   = var.name_prefix
  region = var.do_region
}

data "digitalocean_kubernetes_versions" "pnc_test" {}

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

### MP

provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}

module "pnc_red" {
  source = "./modules/pnc-aws"
  name_prefix = var.name_prefix
  connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
  bgp_password = random_password.bgp_auth_key.result
  redundancy_zone = "red"
  do_region = var.do_region
  do_vpc_ids = [digitalocean_vpc.pnc.id]
  do_local_router_ip = "169.254.0.1/29"
  do_peer_router_ip = "169.254.0.6/29"
  mp_contract_term_months = var.mp_contract_term_months
  mp_do_location = var.mp_do_location_red
  mp_aws_location = var.mp_aws_location_red
  aws_region_full_name = var.aws_region_full_name
  aws_vgw_id = module.aws_vpc.vgw_id
}

module "pnc_blue" {
  count  = var.ha_enabled ? 1 : 0
  source = "./modules/pnc-aws"
  name_prefix = var.name_prefix
  connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
  bgp_password = random_password.bgp_auth_key.result
  redundancy_zone = "blue"
  do_region = var.do_region
  do_vpc_ids = [digitalocean_vpc.pnc.id]
  do_local_router_ip = "169.254.0.9/29"
  do_peer_router_ip = "169.254.0.14/29"
  mp_contract_term_months = var.mp_contract_term_months
  mp_do_location = var.mp_do_location_blue
  mp_aws_location = var.mp_aws_location_blue
  aws_region_full_name = var.aws_region_full_name
  aws_vgw_id = module.aws_vpc.vgw_id
}

## AWS
provider "aws" {
  region = var.aws_region
}

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
}

resource "aws_instance" "t4g_nano" {
  ami                         = data.aws_ami.amazon_linux_arm.id
  instance_type               = "t4g.nano"
  associate_public_ip_address = false
  subnet_id                   = module.aws_vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_ping.id]
}