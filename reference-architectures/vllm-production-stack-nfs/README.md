# vLLM on DOKS with Managed NFS

This reference architecture demonstrates how to deploy vLLM on DigitalOcean Kubernetes Service (DOKS) using Managed NFS for model storage. The architecture provides scalable LLM inference with H100 GPUs and internet-accessible API endpoints via Gateway API.

## Architecture Overview

<img src="./vllm-production-stack-nfs.png" width="700">

1. **DigitalOcean VPC**
   * Deployed in a region with both H100 GPUs and Managed NFS (currently **NYC2** or **ATL1**)
   * A VPC containing all resources with private networking
   * **DOKS Cluster** with management and GPU node pools
   * **Managed NFS Share** for shared model storage

2. **DOKS Cluster**
   * **Management Node Pool**: Auto-scaling basic droplets for system services
   * **GPU Node Pool**: 2x H100 single-GPU droplets (`gpu-h100x1-80gb`) for vLLM inference

3. **vLLM Deployment**
   * **vLLM Workers**: 2 replicas running on H100 GPUs, serving the Llama-3.1-8B-Instruct model
   * **Gateway API**: Cilium Gateway providing internet-accessible inference endpoints

## Why Managed NFS for LLM Model Storage?

Using DigitalOcean Managed NFS for storing LLM model files provides significant advantages over alternatives like init containers or block storage:

| Benefit | Description                                                                                                                        |
|---------|------------------------------------------------------------------------------------------------------------------------------------|
| **Download Once, Use Many** | Model files are downloaded once to shared storage. All vLLM replicas read from the same source with no redundant downloads per pod. |
| **No Init Container Complexity** | vLLM pods mount the NFS share directly. No init containers needed to download models for Spaces object store.                      |
| **Model Version Management** | Store multiple model versions on NFS. Switch models by updating the model path - no rebuilding containers or re-downloading.       |
| **ReadWriteMany Access** | NFS supports concurrent read access from all GPU nodes, unlike block storage which is typically ReadWriteOnce.                     |
| **Managed Service Benefits** | DigitalOcean handles NFS infrastructure, backups, and availability. No self-managed NFS servers to maintain.                       |

## Prerequisites

* DigitalOcean account with H100 GPU quota in a region with both GPUs and Managed NFS (e.g. NYC2 or ATL1)
* HuggingFace account with access to [meta-llama/Llama-3.1-8B-Instruct](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct) (gated model)
* Terraform v1.2+ installed
* `kubectl` CLI installed
* `doctl` CLI configured with API token
* DigitalOcean API Token (`DIGITALOCEAN_ACCESS_TOKEN` environment variable)

## Deployment

This reference architecture uses a hybrid deployment model: Terraform for infrastructure and kubectl for Kubernetes resources.

### Step 1: Deploy Infrastructure (Terraform)

Provision the VPC, DOKS cluster, and NFS share.

First, create a `terraform.tfvars` file with your configuration:

```hcl
name_prefix         = "my-vllm"
region              = "nyc2"  # Must be a region with both H100 GPUs and Managed NFS
vpc_cidr            = "10.200.0.0/22"
doks_cluster_subnet = "172.16.0.0/20"
doks_service_subnet = "192.168.0.0/22"
nfs_size_gb         = 1000
gpu_node_count      = 2
```

Then apply the Terraform configuration:

```bash
cd terraform/1-infra

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 2: Configure kubectl

Get credentials for the DOKS cluster:

```bash
doctl kubernetes cluster kubeconfig save $(terraform output -raw cluster_name)
```

### Step 3: Retrieve NFS Host and Mount Path

The `digitalocean_nfs` Terraform resource outputs the NFS share ID but not the `host` and `mount_path` values needed for Kubernetes PersistentVolume configuration. These must be retrieved via the DigitalOcean API.

```bash
# Get the NFS share ID from Terraform output
NFS_SHARE_ID=$(terraform output -raw nfs_share_id)
REGION="nyc2"

# Retrieve NFS details via API
curl -s -X GET "https://api.digitalocean.com/v2/nfs/${NFS_SHARE_ID}?region=${REGION}" \
  -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
  -H "Content-Type: application/json" | jq .
```

**Example Response:**
```json
{
  "share": {
    "host": "10.200.0.2",
    "mount_path": "/2633050/09064152-bd8d-480d-afd6-5f8bb49188c8",
    "name": "my-vllm-models",
    "status": "ACTIVE"
  }
}
```

**Note:** Wait for the NFS share to reach `ACTIVE` status before proceeding.

### Step 4: Configure NFS Storage

Edit `k8s/pv.yaml` with the NFS host and mount path from the API response:

```yaml
nfs:
  server: <NFS_HOST>       # e.g., 10.200.0.2
  path: <NFS_MOUNT_PATH>   # e.g., /2633050/09064152-bd8d-480d-afd6-5f8bb49188c8
```

Apply the namespace, PersistentVolume, and PersistentVolumeClaim:

```bash
cd ../../
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/pv.yaml
kubectl apply -f k8s/pvc.yaml
```

### Step 5: Configure HuggingFace Token

Edit `k8s/hf-secret.yaml` with your HuggingFace token:

```yaml
stringData:
  HF_TOKEN: <YOUR_HUGGINGFACE_TOKEN>
```

Apply the secret:

```bash
kubectl apply -f k8s/hf-secret.yaml
```

### Step 6: Download Model to NFS

Run the model download job to download Llama-3.1-8B-Instruct to the NFS share:

```bash
kubectl apply -f k8s/model-download-job.yaml

# Wait for the job to complete (may take several minutes)
kubectl wait --for=condition=complete job/model-download -n vllm --timeout=10m

# Verify the job succeeded
kubectl logs job/model-download -n vllm
```

### Step 7: Deploy vLLM

Deploy vLLM with Gateway API for internet access:

```bash
kubectl apply -f k8s/vllm-deployment.yaml
kubectl apply -f k8s/vllm-service.yaml
kubectl apply -f k8s/gateway.yaml

# Wait for pods to be ready (may take several minutes for GPU scheduling)
kubectl wait --for=condition=ready pod -l app=vllm -n vllm --timeout=10m
```

## Verification

### Check Pod Status

```bash
kubectl get pods -n vllm -o wide
```

Expected output shows 2 vLLM pods running on GPU nodes:
```
NAME                    READY   STATUS    RESTARTS   AGE   NODE
vllm-xxx-xxx            1/1     Running   0          5m    vllm-test-gpu-h100-xxx
vllm-xxx-yyy            1/1     Running   0          5m    vllm-test-gpu-h100-yyy
```

### Get Gateway External IP

```bash
kubectl get gateway vllm-gateway -n vllm
```

### Test Inference via Gateway

```bash
GATEWAY_IP=$(kubectl get gateway vllm-gateway -n vllm -o jsonpath='{.status.addresses[0].value}')

# List available models
curl -s http://${GATEWAY_IP}/v1/models | jq .

# Test chat completion
curl -s http://${GATEWAY_IP}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 50
  }' | jq .
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for all resource names | `string` | n/a | yes |
| `region` | DigitalOcean region (must have H100 GPUs and Managed NFS) | `string` | n/a | yes |
| `vpc_cidr` | CIDR block for VPC | `string` | n/a | yes |
| `doks_cluster_subnet` | CIDR block for DOKS cluster subnet | `string` | n/a | yes |
| `doks_service_subnet` | CIDR block for DOKS service subnet | `string` | n/a | yes |
| `nfs_size_gb` | Size of NFS share in GB for model storage | `number` | n/a | yes |
| `gpu_node_count` | Number of H100 GPU nodes in the GPU node pool | `number` | `0` | no |
| `doks_control_plane_ha` | Enable high availability for DOKS control plane | `bool` | `false` | no |
| `management_node_pool_min_nodes` | Minimum nodes in management node pool | `number` | `2` | no |
| `management_node_pool_max_nodes` | Maximum nodes in management node pool | `number` | `3` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC |
| `cluster_id` | ID of the DOKS cluster |
| `cluster_name` | Name of the DOKS cluster |
| `cluster_endpoint` | Endpoint URL for the DOKS cluster API |
| `nfs_share_id` | ID of the NFS share (use API to get host/mount path) |
| `nfs_share_name` | Name of the NFS share |
| `gpu_node_pool_id` | ID of the GPU node pool |
| `gpu_node_pool_name` | Name of the GPU node pool |

## Cleanup

Remove resources in reverse order:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/gateway.yaml
kubectl delete -f k8s/vllm-service.yaml
kubectl delete -f k8s/vllm-deployment.yaml
kubectl delete -f k8s/pvc.yaml
kubectl delete -f k8s/pv.yaml
kubectl delete -f k8s/hf-secret.yaml
kubectl delete -f k8s/namespace.yaml

# Destroy infrastructure
cd terraform/1-infra
terraform destroy
```

## Production Considerations

This reference architecture uses simple round-robin load balancing via Gateway API. For production deployments, consider:

* **KV Cache Aware Routing**: Routes requests to replicas that already have relevant KV cache entries, reducing redundant computation
* **Prefix Aware Routing**: Routes requests with similar prompts to the same replica to maximize prefix cache hits
* **Model Replicas**: Increase `replicas` in the deployment for higher throughput
* **Resource Limits**: Configure appropriate memory limits based on your model size
* **Health Checks**: Tune readiness/liveness probe timings based on model load time
* **TLS Termination**: Add TLS certificates to the Gateway for HTTPS endpoints

These optimizations can significantly improve throughput and reduce latency for multi-replica deployments.

## Troubleshooting

### Pods Not Scheduling on GPU Nodes

**Symptom**: vLLM pods stuck in `Pending` state

**Solution**: Verify GPU node pool exists and has available nodes:
```bash
kubectl get nodes -l doks.digitalocean.com/node-pool=<gpu-node-pool-name>
kubectl describe node <gpu-node-name> | grep -A5 "Allocatable:"
```

### Model Download Job Fails

**Symptom**: `model-download` job shows error

**Solution**: Check job logs and verify HuggingFace token:
```bash
kubectl logs job/model-download -n vllm
```

Common issues:
* Invalid HuggingFace token
* No access to gated Llama model (request access on HuggingFace)
* NFS mount issues (verify PV/PVC are bound)

### Gateway Not Getting External IP

**Symptom**: Gateway shows no address

**Solution**: Verify Cilium Gateway API is enabled:
```bash
kubectl get gatewayclass
kubectl describe gateway vllm-gateway -n vllm
```

### vLLM Pods Crash on Startup

**Symptom**: Pods in `CrashLoopBackOff`

**Solution**: Check pod logs for model loading errors:
```bash
kubectl logs -l app=vllm -n vllm --tail=100
```

Common issues:
* Model not found on NFS (run download job first)
* Insufficient GPU memory
* Missing HuggingFace token for tokenizer access

## References

* [vLLM Documentation](https://docs.vllm.ai/)
* [DigitalOcean Managed NFS](https://docs.digitalocean.com/products/storage/nfs/)
* [DigitalOcean GPU Droplets](https://docs.digitalocean.com/products/droplets/concepts/gpu/)
* [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
* [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
