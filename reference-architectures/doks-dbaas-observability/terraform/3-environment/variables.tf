variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "fqdn" {
  description = "FQDN for the DNS record that will be created for the demo application. Must be a DO DNS managed domain."
  type        = string
}
