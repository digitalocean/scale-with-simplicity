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
# Like the Kubernetes provider, it is configured with the DOKS cluster's credentials.
provider "helm" {
  kubernetes = {
    host  = data.digitalocean_kubernetes_cluster.doks_cluster.endpoint
    token = data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(
      data.digitalocean_kubernetes_cluster.doks_cluster.kube_config[0].cluster_ca_certificate
    )
  }
}

# This resource creates a Kubernetes namespace named "cluster-services".
# Namespaces provide a scope for names and are a way to divide cluster resources
# between multiple users or applications. All the services in this stack will be
# deployed into this namespace.
resource "kubernetes_namespace_v1" "cluster_services" {
  metadata {
    annotations = {
      name = "cluster_services"
    }
    name = "cluster-services"
  }
}


# This resource creates a Kubernetes secret to store the DigitalOcean API access token.
# This token is required by services that need to interact with the DigitalOcean API,
# such as ExternalDNS for managing DNS records.
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

# This resource deploys cert-manager using its Helm chart.
# Cert-manager is a powerful tool that automates the management and issuance of TLS certificates
# from various issuing sources, like Let's Encrypt. It ensures that certificates are valid and
# up to date, and attempts to renew certificates at a configured time before expiry.
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cluster-services"
  set = [
    { name = "crds.enabled", value = true },
    { name = "config.apiVersion", value = "controller.config.cert-manager.io/v1alpha1" },
    { name = "config.kind", value = "ControllerConfiguration" },
    { name = "config.enableGatewayAPI", value = true },
  ]
}




# This resource deploys the Kubernetes Metrics Server.
# The Metrics Server is a cluster-wide aggregator of resource usage data.
# It's a crucial component for features like the Horizontal Pod Autoscaler (HPA),
# which automatically scales the number of pods in a deployment based on CPU or memory usage.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  namespace  = "cluster-services"
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

# This resource deploys ExternalDNS, a tool that synchronizes exposed Kubernetes Services
# and Ingresses with DNS providers. In this case, it's configured to use the DigitalOcean
# DNS provider. It watches for new Services and Ingresses and automatically creates
# corresponding DNS records, making them accessible via a public domain name.
# It uses the DigitalOcean API token stored in the previously created secret.
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "cluster-services"
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
      },
    ]
    # Policy of sync means that external-dns will remove records it created when the corresponding service is also removed.
    policy = "sync"
    # txtOwnerId ensures that if more than one cert-manager is managing a DNS domain that they can determine which
    # records are owned by each cert-manager.
    txtOwnerId = var.name_prefix
    sources = [
      "service",
      "ingress",
      # Only including GA Route Resources.
      "gateway-grpcroute",
      "gateway-httproute",
    ]
  })]
}
