output "route_name" {
  description = "Name of the Route CRD"
  value       = "default-egress-via-nat"
}

output "cluster_endpoint" {
  description = "Endpoint of the DOKS cluster"
  value       = data.digitalocean_kubernetes_cluster.cluster.endpoint
}
