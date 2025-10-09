variable do_token {}

variable region {
  type = string
  default = "blr1"
}

variable "nat_gateway_name" {
  type = string
  default = "nat-gateway"
}

# Resource 3: Droplet(non K8 host) related
variable "droplet_image" {
  type = string
  default = "ubuntu-24-04-x64"
}

variable "droplet_size" {
  type = string
  default = "s-1vcpu-512mb-10gb"
}

# Resource 4: K8 cluster related
variable "node_count" {
  type = number
  default = 2
}
