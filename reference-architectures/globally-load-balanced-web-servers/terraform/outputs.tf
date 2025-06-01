output "glb_fqdn" {
  description = "FQDN of the GLB used for testing"
  value       = var.domain
}

output "rlb_fqdns" {
  description = "List fo FQDNs of RLBs used for testing"
  value       = [for vpc in var.vpcs : "${vpc.region}.${var.domain}"]
}

