variable "name_prefix" {
  description = "Name Prefix to use for the resources created by this module"
  type        = string
}

variable "do_region" {
  type = string
}

variable "doks_cluster_subnet" {
  description = "CIDR for the DOKS Cluster Subnet"
  type        = string
}

variable "doks_service_subnet" {
  description = "CIDR for the DOKS Service Subnet"
  type        = string
}

variable "mp_contract_term_months" {
  type    = number
  default = 1
}

variable "mp_do_location_red" {
  description = "The Megaport location name that is used for the MCR and DO VXC in the Red Redundancy Zone"
  type        = string
}

variable "mp_aws_location_red" {
  description = "The Megaport location name that is used for AWS VXC in the Red Redundancy Zone"
  type        = string
}

variable "mp_do_location_blue" {
  description = "The Megaport location name used for the MCR and DO VXC in the Blue Redundancy Zone"
  type        = string
}

variable "mp_aws_location_blue" {
  description = "The Megaport location name used for AWS VXC in the Blue Redundancy Zone"
  type        = string
}

variable "ha_enabled" {
  description = "Will create a second connection between DO and AWS using the Blue Redundancy Zone"
  type        = bool
  default     = false
  validation {
    condition = (
      !var.ha_enabled ||
      (var.mp_do_location_blue != null && var.mp_aws_location_blue != null)
    )
    error_message = "When ha_enabled is true, both mp_do_location_blue and mp_aws_location_blue must be set."
  }
}

variable "aws_region" {
  type = string
}

variable "aws_vpc_cidr" {
  description = "CIDR to use for the AWS VPC"
  type        = string
}

variable "aws_region_full_name" {
  type = string
}
