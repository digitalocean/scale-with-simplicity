output "doks_cluster_name" {
  description = "Name of the created DOKS cluster"
  value = digitalocean_kubernetes_cluster.primary_cluster.name
}