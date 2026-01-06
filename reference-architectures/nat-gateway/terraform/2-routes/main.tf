# Data source to read outputs from Stack 1 (1-infra)
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "../1-infra/terraform.tfstate"
  }
}

# Data source to reference the cluster created in Stack 1
data "digitalocean_kubernetes_cluster" "cluster" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# Route CRD to override default route to NAT Gateway
resource "kubernetes_manifest" "default_route_via_nat" {
  manifest = yamldecode(templatefile("${path.module}/../../k8s/route.yaml", {
    gateway_ip = data.terraform_remote_state.infra.outputs.nat_gateway_gateway_ip
  }))

  depends_on = [
    # Ensure cluster is ready and Routing Agent is active
    data.digitalocean_kubernetes_cluster.cluster
  ]
}
