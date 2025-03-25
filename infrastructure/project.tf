resource "digitalocean_project" "project" {
  name        = var.project_name
  description = "Reference Architectures for building Distributed Systems"
  purpose     = "Demo"
  environment = "Development"
} 