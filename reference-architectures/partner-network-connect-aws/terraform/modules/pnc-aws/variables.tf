variable "name_prefix" {
  description = "Name Prefix to use for the resources created by this module"
  type        = string
}

variable "connection_bandwidth_in_mbps" {
  description = "MBps to support for all links between DO and AWS"
  type        = number
}

variable "do_region" {
  type    = string
}

variable "mp_contract_term_months" {
  type    = number
}

variable "mp_do_location" {
  description = "The Megaport location name that is used for the MCR and DO VXC in the Red Redundancy Zone"
  type        = string
}

variable "mp_aws_location" {
  description = "The Megaport location name that is used for AWS VXC in the Red Redundancy Zone"
  type        = string
}

variable "aws_region_full_name" {
  type    = string
}

variable "aws_vgw_id" {
  type = string
}

variable "do_vpc_ids" {
  type = list(string)
}

variable "bgp_password" {
  type = string
}

variable "redundancy_zone" {
  type = string
  validation {
    condition     = contains(["red", "blue"], var.redundancy_zone)
    error_message = "redundancy_zone must be either red or blue."
  }
}

variable "do_local_router_ip" {
  type = string
}

variable "do_peer_router_ip" {
  type = string
}

variable "aws_asn" {
  type = number
  default = 64512
}

variable "do_asn" {
  type = number
  default = 64532
}

variable "mp_asn" {
  default = 133937
}


