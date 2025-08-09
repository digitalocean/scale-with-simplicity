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

resource "kubernetes_namespace_v1" "cluster_services" {
  metadata {
    annotations = {
      name = "cluster_services"
    }
    name = "cluster-services"
  }
}


# DO API Access Token for controllers that need to interact with DO API
resource "kubernetes_secret_v1" "digitalocean_access_token" {
  metadata {
    name      = "digitalocean-access-token"
    namespace = "cluster-services"
  }
  data = {
    token = var.digitalocean_access_token
  }
  type = "Opaque"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  # using older version to work around https://github.com/cert-manager/cert-manager/issues/6805
  # Tried using the feature gate ACMEHTTP01IngressPathTypeExact, but was unable to get it to work
  # Will revisit when we replace nginx-ingress with cilium-ingress in Q4.
  version = "1.17.2"
  namespace        = "cluster-services"
  set = [
    {
      name  = "installCRDs"
      value = true
    },
  ]
}

# To be removed once Cilium Ingress is supported
# We can't use "controller.metrics.serviceMonitor.enabled" here as the ServiceMonitor is created as part of this TF module
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "cluster-services"
  set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-name"
      value = var.name_prefix
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-type"
      value = "REGIONAL_NETWORK"
    },
    {
      name  = "controller.replicaCount"
      value = 2
    },
    {
      name  = "controller.metrics.enabled"
      value = true
    },
  ]
}


# One ConfigMap for all Grafana dashboards
resource "kubernetes_config_map_v1" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = "cluster-services"
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "ingress-nginx-overview.json"              = file("${path.module}/dashboards/ingress-nginx-overview.json")
    "telegraf-system-metrics.json"  = file("${path.module}/dashboards/telegraf-system-metrics.json")
  }
}

# DO Marketplace base values
data "http" "kube_prometheus_stack_values" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/kube-prometheus-stack/values.yml"
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "cluster-services"

  values = [data.http.kube_prometheus_stack_values.response_body]

  set = [
    {
      name  = "prometheus.prometheusSpec.serviceDiscoveryRole"
      value = "EndpointSlice"
    },
    # kubeControllerManager runs on management cluster
    {
      name  = "defaultRules.rules.kubeControllerManager"
      value = false
    },
    {
      name  = "kubeControllerManager.enabled"
      value = false
    },
    # kubeProxy replaced by Cilium
    {
      name  = "defaultRules.rules.kubeProxy"
      value = false
    },
    {
      name  = "kubeProxy.enabled"
      value = false
    },

    # Point Grafana at our single ConfigMap (folder name "custom")
    {
      name  = "grafana.dashboardsConfigMaps.custom"
      value = kubernetes_config_map_v1.grafana_dashboards.metadata[0].name
    },
  ]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server"
  chart            = "metrics-server"
  namespace        = "cluster-services"
  set = [
    {
      name  = "replicas"
      value = 2
    },
    {
      name  = "apiService.create"
      value = true
    },
  ]
}

# External DNS
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "cluster-services"
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
