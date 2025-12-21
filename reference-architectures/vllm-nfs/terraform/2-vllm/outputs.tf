output "namespace" {
  description = "The Kubernetes namespace where vLLM is deployed"
  value       = kubernetes_manifest.namespace.manifest.metadata.name
}

output "service_name" {
  description = "The name of the vLLM ClusterIP service"
  value       = kubernetes_manifest.vllm_service.manifest.metadata.name
}

output "service_port" {
  description = "The port of the vLLM service"
  value       = 8000
}

output "gateway_name" {
  description = "The name of the Gateway resource for external access"
  value       = kubernetes_manifest.gateway.manifest.metadata.name
}

output "model_id" {
  description = "The HuggingFace model ID being served"
  value       = var.model_id
}

output "model_name" {
  description = "The model name used for inference requests"
  value       = local.model_name
}
