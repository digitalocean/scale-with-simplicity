data "digitalocean_kubernetes_cluster" "doks_cluster" {
  name = var.name_prefix
}

provider "kubernetes" {
  host  = data.digitalocean_kubernetes_cluster.doks_cluster.endpoint
  token = data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes = {
    host  = data.digitalocean_kubernetes_cluster.doks_cluster.endpoint
    token = data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(
      data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].cluster_ca_certificate
    )
  }
}


# Marketplace apps
data "http" "kube_prometheus_stack_values" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/kube-prometheus-stack/values.yml"
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "75.9.0"
  namespace        = "kube-prometheus-stack"
  create_namespace = true
  values           = [data.http.kube_prometheus_stack_values.response_body]
}

data "http" "metrics_server_values" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/metrics-server/values.yml"
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server"
  chart            = "metrics-server"
  version          = "3.12.2"
  namespace        = "metrics-server"
  create_namespace = true
  values           = [data.http.metrics_server_values.response_body]
}

