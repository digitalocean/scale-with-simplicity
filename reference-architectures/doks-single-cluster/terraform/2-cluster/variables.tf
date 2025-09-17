variable "name_prefix" {
  description = "Name to use for the name prefix of the created resources."
  type        = string
}

variable "grafana_password" {
  description = "Password used for Grafana UI"
  default = "do-demo"
}

variable "digitalocean_access_token" {
  description = "A DigitalOcean API Access Token used by some of the installed controllers, such as external-dns, to interact with DO APU"
}

variable "log_sink_fqdn" {
  description = "FQDN for the log sink NLB endpoint that rsyslog will send logs to"
  type        = string
}