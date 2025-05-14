output "glb_fqdn" {
  description = "URL "
  value       = var.domain
}

output "rlb_fqdns" {
  value = [for vpc in var.vpcs : "${vpc.region}.${var.domain}"]
}

