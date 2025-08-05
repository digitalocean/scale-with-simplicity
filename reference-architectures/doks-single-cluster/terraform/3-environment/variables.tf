variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "region" {
  description = "DO region slug for the region the droplet will be deployed into"
  type        = string
}
