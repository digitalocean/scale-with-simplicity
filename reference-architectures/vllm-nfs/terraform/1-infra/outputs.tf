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
  description = "The ID of the NFS share"
  value       = digitalocean_nfs.models.id
}

output "nfs_share_name" {
  description = "The name of the NFS share"
  value       = digitalocean_nfs.models.name
}

output "nfs_host" {
  description = "NFS server IP address for PersistentVolume configuration"
  value       = digitalocean_nfs.models.host
}

output "nfs_mount_path" {
  description = "NFS mount path for PersistentVolume configuration"
  value       = digitalocean_nfs.models.mount_path
}

output "nfs_size_gb" {
  description = "Size of the NFS share in GB"
  value       = digitalocean_nfs.models.size
}

output "gpu_node_pool_id" {
  description = "The ID of the GPU node pool"
  value       = digitalocean_kubernetes_node_pool.gpu.id
}

output "gpu_node_pool_name" {
  description = "The name of the GPU node pool (used for Helm values nodeSelector)"
  value       = digitalocean_kubernetes_node_pool.gpu.name
}
