variable "name_prefix" {
  description = "Name Prefix to use for the resources created by this module"
  type        = string
  default     = "jkeegan-test"
}

variable "connection_bandwidth_in_mbps" {
  description = "MBps to support for all links between DO and AWS"
  type        = number
  default     = 1000
}

variable "do_region" {
  type    = string
  default = "nyc1"
}

variable "doks_cluster_subnet" {
  description = "CIDR for the DOKS Cluster Subnet"
  type        = string
  default     = "172.16.0.0/16"
}

variable "doks_service_subnet" {
  description = "CIDR for the DOKS Service Subnet"
  type        = string
  default     = "172.17.0.0/16"
}

variable "mp_contract_term_months" {
  type    = number
  default = 1
}

variable "mp_do_location_red" {
  description = "The Megaport location name that is used for the MCR and DO VXC in the Red Redundancy Zone"
  type        = string
  default     = "Digital Realty New York JFK12 (NYC1)"
}

variable "mp_do_location_blue" {
  description = "The Megaport location name that is used for the MCR and DO VXC in the Blue Redundancy Zone"
  type        = string
  default     = "Equinix NY9"
}

variable "mp_aws_location_red" {
  description = "The Megaport location name that is used for AWS VXC in the Red Redundancy Zone"
  type        = string
  default     = "CoreSite NY1"
}

variable "mp_aws_location_blue" {
  description = "The Megaport location name that is used for AWS VXC in the Blue Redundancy Zone"
  type        = string
  default     = "Equinix DC4"
}


variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_vpc_cidr" {
  description = "CIDR to use for the AWS VPC"
  type        = string
  default     = "192.168.0.0/24"
}
