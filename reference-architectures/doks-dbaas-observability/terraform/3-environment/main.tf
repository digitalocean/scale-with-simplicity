# This data source retrieves the details of the DigitalOcean Kubernetes (DOKS) cluster.
# This is necessary to configure the Kubernetes and Helm providers to interact with the correct cluster.
data "digitalocean_kubernetes_cluster" "doks_cluster" {
  name = var.name_prefix
}

# The Kubernetes provider is used to interact with the resources in a Kubernetes cluster.
provider "kubernetes" {
  host  = data.digitalocean_kubernetes_cluster.doks_cluster.endpoint
  token = data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].cluster_ca_certificate
  )
}

# The Helm provider is used to manage applications on Kubernetes using Helm charts.
provider "helm" {
  kubernetes = {
    host  = data.digitalocean_kubernetes_cluster.doks_cluster.endpoint
    token = data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(
      data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].cluster_ca_certificate
    )
  }
}

resource "kubernetes_namespace_v1" "demo" {
  metadata {
    annotations = {
      name = "demo"
    }
    name = "demo"
  }
}
