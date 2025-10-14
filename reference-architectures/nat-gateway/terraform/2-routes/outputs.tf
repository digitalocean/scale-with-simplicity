output "route_name" {
  value = kubernetes_manifest.default_egress_via_nat.object.metadata.name
}
