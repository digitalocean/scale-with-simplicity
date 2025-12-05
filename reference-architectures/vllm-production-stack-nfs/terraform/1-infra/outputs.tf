output "vpc_id" {
  description = "The ID of the VPC"
  value       = digitalocean_vpc.vllm.id
}

output "cluster_id" {
  description = "The ID of the DOKS cluster"
  value       = digitalocean_kubernetes_cluster.vllm.id
}

output "cluster_name" {
  description = "The name of the DOKS cluster"
  value       = digitalocean_kubernetes_cluster.vllm.name
}

output "cluster_endpoint" {
  description = "The endpoint URL for the DOKS cluster API"
  value       = digitalocean_kubernetes_cluster.vllm.endpoint
}

output "nfs_share_id" {
  description = "The ID of the NFS share (use DigitalOcean console/API to get host and mount path)"
  value       = digitalocean_nfs.models.id
}

output "nfs_share_name" {
  description = "The name of the NFS share"
  value       = digitalocean_nfs.models.name
}

output "gpu_node_pool_id" {
  description = "The ID of the GPU node pool"
  value       = digitalocean_kubernetes_node_pool.gpu.id
}

output "gpu_node_pool_name" {
  description = "The name of the GPU node pool (used for Helm values nodeSelector)"
  value       = digitalocean_kubernetes_node_pool.gpu.name
}
