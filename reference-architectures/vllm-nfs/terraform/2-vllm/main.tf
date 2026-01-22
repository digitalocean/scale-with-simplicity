locals {
  # Values from Stack 1 remote state
  nfs_host           = data.terraform_remote_state.infra.outputs.nfs_host
  nfs_mount_path     = data.terraform_remote_state.infra.outputs.nfs_mount_path
  nfs_size_gb        = data.terraform_remote_state.infra.outputs.nfs_size_gb
  gpu_node_pool_name = data.terraform_remote_state.infra.outputs.gpu_node_pool_name

  # Extract model name from model_id (e.g., "Qwen/Qwen2.5-0.5B-Instruct" -> "Qwen2.5-0.5B-Instruct")
  model_name = element(split("/", var.model_id), 1)
}

# 1. Namespace for all vLLM resources
resource "kubernetes_manifest" "namespace" {
  manifest = yamldecode(file("${path.module}/../../k8s/namespace.yaml"))
}

# 2. PersistentVolume using NFS from Stack 1
resource "kubernetes_manifest" "pv" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/pv.yaml", {
    nfs_host       = local.nfs_host
    nfs_mount_path = local.nfs_mount_path
    nfs_size_gb    = local.nfs_size_gb
  }))

  depends_on = [kubernetes_manifest.namespace]
}

# 3. PersistentVolumeClaim to bind to the NFS PV
resource "kubernetes_manifest" "pvc" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/pvc.yaml", {
    nfs_size_gb = local.nfs_size_gb
  }))

  depends_on = [kubernetes_manifest.pv]
}

# 4. Secret for HuggingFace token
# Note: computed_fields is needed because Kubernetes converts stringData to data (base64)
# and removes stringData from the object, which would otherwise cause drift detection.
resource "kubernetes_manifest" "hf_secret" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/hf-secret.yaml", {
    hf_token = var.hf_token
  }))

  computed_fields = ["stringData"]

  depends_on = [kubernetes_manifest.namespace]
}

# 5. Job to download the model from HuggingFace to NFS
resource "kubernetes_manifest" "model_download_job" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/model-download-job.yaml", {
    model_id   = var.model_id
    model_name = local.model_name
  }))

  wait {
    condition {
      type   = "Complete"
      status = "True"
    }
  }

  timeouts {
    create = "60m"
  }

  depends_on = [
    kubernetes_manifest.pvc,
    kubernetes_manifest.hf_secret
  ]
}

# 6. vLLM Deployment
resource "kubernetes_manifest" "vllm_deployment" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/vllm-deployment.yaml", {
    model_name         = local.model_name
    replicas           = var.replicas
    quantization       = var.quantization
    gpu_node_pool_name = local.gpu_node_pool_name
  }))

  depends_on = [kubernetes_manifest.model_download_job]
}

# 7. PodDisruptionBudget for graceful disruption handling
resource "kubernetes_manifest" "pdb" {
  manifest = yamldecode(file("${path.module}/../../k8s/pdb.yaml"))

  depends_on = [kubernetes_manifest.namespace]
}

# 8. ClusterIP Service for vLLM
resource "kubernetes_manifest" "vllm_service" {
  manifest = yamldecode(file("${path.module}/../../k8s/vllm-service.yaml"))

  depends_on = [kubernetes_manifest.vllm_deployment]
}

# 9. Gateway for external access via Cilium Gateway API
resource "kubernetes_manifest" "gateway" {
  manifest = yamldecode(file("${path.module}/../../k8s/gateway.yaml"))

  depends_on = [kubernetes_manifest.vllm_service]
}

# 10. HTTPRoute to route traffic to vLLM service
resource "kubernetes_manifest" "httproute" {
  manifest = yamldecode(file("${path.module}/../../k8s/httproute.yaml"))

  depends_on = [kubernetes_manifest.gateway]
}
