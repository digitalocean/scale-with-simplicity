variable "region" {
  description = "DigitalOcean region for all resources"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
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

variable "doks_node_count" {
  description = "Number of nodes in the DOKS cluster"
  type        = number
  default     = 1
}

variable "ssh_key_ids" {
  description = "SSH key IDs for droplet access"
  type        = list(string)
  default     = []
}
