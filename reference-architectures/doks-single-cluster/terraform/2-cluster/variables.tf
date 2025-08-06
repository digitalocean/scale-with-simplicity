variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "digitalocean_access_token" {
  description = "A DigitalOcean API Access Token used by some of the installed controllers, such as external-dns, to interact with DO APU"
}