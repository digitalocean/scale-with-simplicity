variable "do_token"        { type = string, sensitive = true, default = null }
variable "region"          { type = string  default = "sfo3" }
variable "vpc_name"        { type = string  default = "ra-nat-vpc" }
variable "nat_gateway_name"{ type = string  default = "ra-nat-gw" }
variable "cluster_name"    { type = string  default = "ra-nat-doks" }
variable "k8s_version"     { type = string  default = "1.30.4-do.0" }
variable "node_size"       { type = string  default = "s-2vcpu-4gb" }
variable "node_count"      { type = number  default = 1 }
variable "droplet_name"    { type = string  default = "ra-nat-droplet" }
variable "droplet_size"    { type = string  default = "s-1vcpu-1gb" }
variable "droplet_image"   { type = string  default = "ubuntu-22-04-x64" }
