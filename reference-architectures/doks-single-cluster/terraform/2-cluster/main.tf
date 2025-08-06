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

# DO API Access Token for controllers that need to interact with DO API
resource "kubernetes_secret_v1" "digitalocean_access_token" {
  metadata {
    name      = "digitalocean-access-token"
    namespace = "kube-system"
  }
  data = {
    token = var.digitalocean_access_token
  }
  type = "Opaque"
}

# DO Marketplace app
data "http" "cert_manager" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/cert-manager/values.yml"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  values           = [data.http.cert_manager.response_body]
}


# DO Marketplace app
data "http" "kube_prometheus_stack_values" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/kube-prometheus-stack/values.yml"
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  # Specifying version due to issue with Prom operator version and support for EndpointSlice
  # See digitalocean_kubernetes_cluster resource in infra module for more details
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
  namespace        = "metrics-server"
  create_namespace = true
  values           = [data.http.metrics_server_values.response_body]
}

# External DNS
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "kube-system"
  values = [yamlencode({
    provider = {
      name = "digitalocean"
    }
    env = [
      {
        name = "DO_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = "digitalocean-access-token"
            key  = "token"
          }
        }
      }
    ]
    # Policy of sync means that external-dns will remove records it created when the corresponding service is also removed.
    policy = "sync"
  })]
}
