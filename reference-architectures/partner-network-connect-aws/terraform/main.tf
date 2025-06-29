locals {
  aws_asn        = 64512
  aws_connection = try([for conn in megaport_vxc.aws.csp_connections : conn if conn.connect_type == "AWS"][0], null)
  aws_connection2 = try([for conn in megaport_vxc.aws2.csp_connections : conn if conn.connect_type == "AWS"][0], null)
  do_asn         = 64532
  mp_asn         = 133937
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



resource "digitalocean_partner_attachment" "megaport" {
  name                         = var.name_prefix
  connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
  region                       = substr(var.do_region, 0, 3)
  naas_provider                = "MEGAPORT"
  # redundancy_zone              = "MEGAPORT_RED"
  vpc_ids = [digitalocean_vpc.pnc.id]
  bgp {
    local_router_ip = "169.254.0.1/29"
    peer_router_asn = local.mp_asn
    peer_router_ip  = "169.254.0.6/29"
    auth_key        = random_password.bgp_auth_key.result
  }
}

data "digitalocean_partner_attachment_service_key" "megaport" {
  attachment_id = digitalocean_partner_attachment.megaport.id
}

resource "digitalocean_partner_attachment" "megaport2" {
  name                         = "${var.name_prefix}-ha"
  connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
  region                       = substr(var.do_region, 0, 3)
  naas_provider                = "MEGAPORT"
  # redundancy_zone              = "MEGAPORT_RED"
  vpc_ids     = [digitalocean_vpc.pnc.id]
  parent_uuid = digitalocean_partner_attachment.megaport.id
  bgp {
    local_router_ip = "169.254.0.9/29"
    peer_router_asn = local.mp_asn
    peer_router_ip  = "169.254.0.14/29"
    auth_key        = random_password.bgp_auth_key.result
  }
}

data "digitalocean_partner_attachment_service_key" "megaport2" {
  attachment_id = digitalocean_partner_attachment.megaport2.id
}


### MP

provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}

data "megaport_location" "nyc" {
  # https://www.megaport.com/megaport-enabled-locations
  name = "Digital Realty New York JFK13 (NYC3)"
}

data "megaport_location" "nyc2" {
  # https://www.megaport.com/megaport-enabled-locations
  name = "Equinix NY2"
}

data "megaport_partner" "aws" {
  connect_type = "AWS"
  company_name = "AWS"
  product_name = "US East (N. Virginia) (us-east-1)"
  # How does a normal person get this?
  location_id = 75
}

data "megaport_partner" "aws2" {
  connect_type = "AWS"
  company_name = "AWS"
  product_name = "US East (N. Virginia) (us-east-1)"
  # How does a normal person get this?
  location_id = 67
}

resource "megaport_mcr" "mcr" {
  product_name         = var.name_prefix
  port_speed           = var.connection_bandwidth_in_mbps
  location_id          = data.megaport_location.nyc.id
  contract_term_months = 1
  diversity_zone       = digitalocean_partner_attachment.megaport.redundancy_zone == "MEGAPORT_RED" ? "red" : digitalocean_partner_attachment.megaport.redundancy_zone == "MEGAPORT_BLUE" ? "blue" : digitalocean_partner_attachment.megaport.redundancy_zone
}

resource "megaport_mcr" "mcr2" {
  product_name         = var.name_prefix
  port_speed           = var.connection_bandwidth_in_mbps
  location_id          = data.megaport_location.nyc.id
  contract_term_months = 1
  diversity_zone       = digitalocean_partner_attachment.megaport2.redundancy_zone == "MEGAPORT_RED" ? "red" : digitalocean_partner_attachment.megaport2.redundancy_zone == "MEGAPORT_BLUE" ? "blue" : digitalocean_partner_attachment.megaport2.redundancy_zone
}

resource "megaport_vxc" "do" {
  product_name         = "${var.name_prefix}-do-vxc"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months
  service_key          = data.digitalocean_partner_attachment_service_key.megaport.value
  a_end = {
    requested_product_uid = megaport_mcr.mcr.product_uid
  }
  a_end_partner_config = {
    partner = "vrouter"
    vrouter_config = {
      interfaces = [
        {
          ip_addresses = [digitalocean_partner_attachment.megaport.bgp[0].peer_router_ip]
          bgp_connections = [{
            password         = digitalocean_partner_attachment.megaport.bgp[0].auth_key
            local_asn        = local.mp_asn
            local_ip_address = split("/", digitalocean_partner_attachment.megaport.bgp[0].peer_router_ip)[0]
            peer_asn         = local.do_asn
            peer_ip_address  = split("/", digitalocean_partner_attachment.megaport.bgp[0].local_router_ip)[0]
          }]
        }
      ]
    }
  }
  b_end = {}
}

resource "megaport_vxc" "do2" {
  product_name         = "${var.name_prefix}-do-vxc-ha"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months
  service_key          = data.digitalocean_partner_attachment_service_key.megaport2.value
  a_end = {
    requested_product_uid = megaport_mcr.mcr2.product_uid
  }
  a_end_partner_config = {
    partner = "vrouter"
    vrouter_config = {
      interfaces = [
        {
          ip_addresses = [digitalocean_partner_attachment.megaport2.bgp[0].peer_router_ip]
          bgp_connections = [{
            password         = digitalocean_partner_attachment.megaport2.bgp[0].auth_key
            local_asn        = local.mp_asn
            local_ip_address = split("/", digitalocean_partner_attachment.megaport2.bgp[0].peer_router_ip)[0]
            peer_asn         = local.do_asn
            peer_ip_address  = split("/", digitalocean_partner_attachment.megaport2.bgp[0].local_router_ip)[0]
          }]
        }
      ]
    }
  }
  b_end = {}
}

resource "megaport_vxc" "aws" {
  product_name         = "${var.name_prefix}-aws-vxc"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months

  a_end = {
    requested_product_uid = megaport_mcr.mcr.product_uid
  }

  b_end = {
    requested_product_uid = data.megaport_partner.aws.product_uid
  }

  b_end_partner_config = {
    partner = "aws"
    aws_config = {
      name          = var.name_prefix
      asn           = local.mp_asn
      amazon_asn    = local.aws_asn
      type          = "private"
      connect_type  = "AWS"
      owner_account = data.aws_caller_identity.current.account_id

    }
  }
}

resource "megaport_vxc" "aws2" {
  product_name         = "${var.name_prefix}-aws-vxc-ha"
  rate_limit           = var.connection_bandwidth_in_mbps
  contract_term_months = var.mp_contract_term_months

  a_end = {
    requested_product_uid = megaport_mcr.mcr2.product_uid
  }

  b_end = {
    requested_product_uid = data.megaport_partner.aws2.product_uid
  }

  b_end_partner_config = {
    partner = "aws"
    aws_config = {
      name          = "${var.name_prefix}-ha"
      asn           = local.mp_asn
      amazon_asn    = local.aws_asn
      type          = "private"
      connect_type  = "AWS"
      owner_account = data.aws_caller_identity.current.account_id

    }
  }
}

## AWS
provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

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


resource "aws_dx_hosted_private_virtual_interface_accepter" "mp_vif" {
  virtual_interface_id = local.aws_connection.vif_id
  vpn_gateway_id       = module.aws_vpc.vgw_id
}

resource "aws_dx_hosted_private_virtual_interface_accepter" "mp_vif2" {
  virtual_interface_id = local.aws_connection2.vif_id
  vpn_gateway_id       = module.aws_vpc.vgw_id
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