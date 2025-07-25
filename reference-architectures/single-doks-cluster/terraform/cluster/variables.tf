variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "region" {
  description = "DO region slug for the region the droplet will be deployed into"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR to use for the DO VPC"
  type        = string
}

variable "doks_cluster_subnet" {
  description = "CIDR for the DOKS Cluster Subnet"
  type        = string
}

variable "doks_service_subnet" {
  description = "CIDR for the DOKS Service Subnet"
  type        = string
}

variable "doks_control_plane_ha" {
  description = "Determines if DOKS Control Plane HA is enabled. Defaults to false."
  type        = bool
  default = false
}

variable "doks_node_pool_min_nodes" {
  description = "Minimum number of nodes in the DOKS node pool"
  type = number
  default = 2
}

variable "doks_node_pool_max_nodes" {
  description = "Maximum number of nodes in the DOKS node pool can autoscale to"
  type = number
  default = 4
}