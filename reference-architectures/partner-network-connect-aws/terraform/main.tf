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
  mp_do_location = var.mp_do_location_red
  mp_aws_location = var.mp_aws_location_red
  aws_region_full_name = var.aws_region_full_name
  aws_vgw_id = module.aws_vpc.vgw_id
}

#
# resource "digitalocean_partner_attachment" "megaport_red" {
#   name                         = "${var.name_prefix}-red"
#   connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
#   region                       = substr(var.do_region, 0, 3)
#   naas_provider                = "MEGAPORT"
#   redundancy_zone              = "MEGAPORT_RED"
#   vpc_ids                      = [digitalocean_vpc.pnc.id]
#   bgp {
#     local_router_ip = "169.254.0.1/29"
#     peer_router_asn = local.mp_asn
#     peer_router_ip  = "169.254.0.6/29"
#     auth_key        = random_password.bgp_auth_key.result
#   }
# }
#
# data "digitalocean_partner_attachment_service_key" "megaport_red" {
#   attachment_id = digitalocean_partner_attachment.megaport_red.id
# }
#
# resource "digitalocean_partner_attachment" "megaport_blue" {
#   count = var.ha_enabled ? 0 : 1
#   name                         = "${var.name_prefix}-blue"
#   connection_bandwidth_in_mbps = var.connection_bandwidth_in_mbps
#   region                       = substr(var.do_region, 0, 3)
#   naas_provider                = "MEGAPORT"
#   redundancy_zone              = "MEGAPORT_BLUE"
#   vpc_ids                      = [digitalocean_vpc.pnc.id]
#   parent_uuid                  = digitalocean_partner_attachment.megaport_red.id
#   bgp {
#     local_router_ip = "169.254.0.9/29"
#     peer_router_asn = local.mp_asn
#     peer_router_ip  = "169.254.0.14/29"
#     auth_key        = random_password.bgp_auth_key.result
#   }
# }
#
# data "digitalocean_partner_attachment_service_key" "megaport_blue" {
#   count = var.ha_enabled ? 0 : 1
#   attachment_id = digitalocean_partner_attachment.megaport_blue[0].id
# }


### MP

provider "megaport" {
  environment           = "production"
  accept_purchase_terms = true
}
#
# data "megaport_location" "do_red" {
#   # https://www.megaport.com/megaport-enabled-locations
#   name = var.mp_do_location_red
# }
#
# data "megaport_location" "do_blue" {
#   count = var.ha_enabled ? 0 : 1
#   # https://www.megaport.com/megaport-enabled-locations
#   name = var.mp_do_location_blue
# }
#
# data "megaport_location" "aws_red" {
#   # https://www.megaport.com/megaport-enabled-locations
#   name = var.mp_aws_location_red
# }
#
# data "megaport_location" "aws_blue" {
#   count = var.ha_enabled ? 0 : 1
#   # https://www.megaport.com/megaport-enabled-locations
#   name = var.mp_aws_location_blue
# }
#
# data "megaport_partner" "aws_red" {
#   connect_type = "AWS"
#   company_name = "AWS"
#   product_name = "US East (N. Virginia) (us-east-1)"
#   location_id = data.megaport_location.aws_red.id
# }
#
# data "megaport_partner" "aws_blue" {
#   count = var.ha_enabled ? 0 : 1
#   connect_type = "AWS"
#   company_name = "AWS"
#   product_name = "US East (N. Virginia) (us-east-1)"
#   location_id = data.megaport_location.aws_blue[0].id
# }
#
# resource "megaport_mcr" "mcr_red" {
#   product_name         = "${var.name_prefix}-red"
#   port_speed           = var.connection_bandwidth_in_mbps
#   location_id          = data.megaport_location.do_red.id
#   contract_term_months = var.mp_contract_term_months
#   diversity_zone       = "red"
# }
#
# resource "megaport_mcr" "mcr_blue" {
#   count = var.ha_enabled ? 0 : 1
#   product_name         = "${var.name_prefix}-blue"
#   port_speed           = var.connection_bandwidth_in_mbps
#   location_id          = data.megaport_location.do_blue[0].id
#   contract_term_months = var.mp_contract_term_months
#   diversity_zone       = "blue"
# }
#
# resource "megaport_vxc" "do_red" {
#   product_name         = "${var.name_prefix}-do-red"
#   rate_limit           = var.connection_bandwidth_in_mbps
#   contract_term_months = var.mp_contract_term_months
#   service_key          = data.digitalocean_partner_attachment_service_key.megaport_red.value
#   a_end = {
#     requested_product_uid = megaport_mcr.mcr_red.product_uid
#   }
#   a_end_partner_config = {
#     partner = "vrouter"
#     vrouter_config = {
#       interfaces = [
#         {
#           ip_addresses = [digitalocean_partner_attachment.megaport_red.bgp[0].peer_router_ip]
#           bgp_connections = [{
#             password         = digitalocean_partner_attachment.megaport_red.bgp[0].auth_key
#             local_asn        = local.mp_asn
#             local_ip_address = split("/", digitalocean_partner_attachment.megaport_red.bgp[0].peer_router_ip)[0]
#             peer_asn         = local.do_asn
#             peer_ip_address  = split("/", digitalocean_partner_attachment.megaport_red.bgp[0].local_router_ip)[0]
#           }]
#         }
#       ]
#     }
#   }
#   b_end = {}
# }
#
# resource "megaport_vxc" "do_blue" {
#   count = var.ha_enabled ? 0 : 1
#   product_name         = "${var.name_prefix}-do-blue"
#   rate_limit           = var.connection_bandwidth_in_mbps
#   contract_term_months = var.mp_contract_term_months
#   service_key          = data.digitalocean_partner_attachment_service_key.megaport_blue[0].value
#   a_end = {
#     requested_product_uid = megaport_mcr.mcr_blue[0].product_uid
#   }
#   a_end_partner_config = {
#     partner = "vrouter"
#     vrouter_config = {
#       interfaces = [
#         {
#           ip_addresses = [digitalocean_partner_attachment.megaport_blue[0].bgp[0].peer_router_ip]
#           bgp_connections = [{
#             password         = digitalocean_partner_attachment.megaport_blue[0].bgp[0].auth_key
#             local_asn        = local.mp_asn
#             local_ip_address = split("/", digitalocean_partner_attachment.megaport_blue[0].bgp[0].peer_router_ip)[0]
#             peer_asn         = local.do_asn
#             peer_ip_address  = split("/", digitalocean_partner_attachment.megaport_blue[0].bgp[0].local_router_ip)[0]
#           }]
#         }
#       ]
#     }
#   }
#   b_end = {}
# }
#
# resource "megaport_vxc" "aws_red" {
#   product_name         = "${var.name_prefix}-aws-red"
#   rate_limit           = var.connection_bandwidth_in_mbps
#   contract_term_months = var.mp_contract_term_months
#
#   a_end = {
#     requested_product_uid = megaport_mcr.mcr_red.product_uid
#   }
#
#   b_end = {
#     requested_product_uid = data.megaport_partner.aws_red.product_uid
#   }
#
#   b_end_partner_config = {
#     partner = "aws"
#     aws_config = {
#       name          = "${var.name_prefix}-red"
#       asn           = local.mp_asn
#       amazon_asn    = local.aws_asn
#       type          = "private"
#       connect_type  = "AWS"
#       owner_account = data.aws_caller_identity.current.account_id
#
#     }
#   }
# }
#
# resource "megaport_vxc" "aws_blue" {
#   count = var.ha_enabled ? 0 : 1
#   product_name         = "${var.name_prefix}-aws-blue"
#   rate_limit           = var.connection_bandwidth_in_mbps
#   contract_term_months = var.mp_contract_term_months
#
#   a_end = {
#     requested_product_uid = megaport_mcr.mcr_blue[0].product_uid
#   }
#
#   b_end = {
#     requested_product_uid = data.megaport_partner.aws_blue[0].product_uid
#   }
#
#   b_end_partner_config = {
#     partner = "aws"
#     aws_config = {
#       name          = "${var.name_prefix}-blue"
#       asn           = local.mp_asn
#       amazon_asn    = local.aws_asn
#       type          = "private"
#       connect_type  = "AWS"
#       owner_account = data.aws_caller_identity.current.account_id
#
#     }
#   }
# }

## AWS
provider "aws" {
  region = var.aws_region
}

# data "aws_caller_identity" "current" {}

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


# resource "aws_dx_hosted_private_virtual_interface_accepter" "mp_vif_red" {
#   virtual_interface_id = local.aws_connection_red.vif_id
#   vpn_gateway_id       = module.aws_vpc.vgw_id
# }
#
# resource "aws_dx_hosted_private_virtual_interface_accepter" "mp_vif_blue" {
#   count = var.ha_enabled ? 0 : 1
#   virtual_interface_id = local.aws_connection_blue[0].vif_id
#   vpn_gateway_id       = module.aws_vpc.vgw_id
# }

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