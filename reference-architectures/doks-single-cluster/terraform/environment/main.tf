locals {
  tags = [
    "single-doks-cluster",
    var.name_prefix
  ]
}

data "digitalocean_vpc" "doks" {
  name = var.name_prefix
}

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

# AdService Postgres DB
resource "digitalocean_database_cluster" "adservice" {
  name                 = "${var.name_prefix}-adservice-pg"
  engine               = "pg"
  version              = "17"
  size                 = "db-s-1vcpu-1gb"
  region               = var.region
  node_count           = 1
  private_network_uuid = data.digitalocean_vpc.doks.id
  tags                 = local.tags
}


resource "kubernetes_secret_v1" "adservice_database" {
  metadata {
    name      = "adservice-database"
    namespace = "default"
  }
  data = {
    postgres-password = digitalocean_database_cluster.adservice.password
  }
  type = "Opaque"
}

resource "kubernetes_config_map_v1" "adservice_database_configuration" {
  metadata {
    name      = "adservice-database-configuration"
    namespace = "default"
  }
  data = {
    postgres-password = digitalocean_database_cluster.adservice.password
    DB_HOST : digitalocean_database_cluster.adservice.private_host
    DB_NAME : digitalocean_database_cluster.adservice.database
    DB_PORT : digitalocean_database_cluster.adservice.port
    DB_SSL_MODE : "require"
    DB_USER : digitalocean_database_cluster.adservice.user
  }
}


# CartService ValKey DB
resource "digitalocean_database_cluster" "cart_service" {
  name                 = "${var.name_prefix}-cart-service-valkey"
  engine               = "valkey"
  version              = "8"
  size                 = "db-s-1vcpu-1gb"
  region               = var.region
  node_count           = 1
  private_network_uuid = data.digitalocean_vpc.doks.id
  tags                 = local.tags
}

resource "kubernetes_secret_v1" "cart_database" {
  metadata {
    name      = "cartservice-database"
    namespace = "default"
  }
  data = {
    connectionString = digitalocean_database_cluster.cart_service.private_uri
  }
  type = "Opaque"
}

# microservices-demo app
resource "helm_release" "microservices_demo" {
  chart = "oci://ghcr.io/do-solutions/microservices-demo"
  name  = "demo"
  set = [
    {
      name : "devDeployment"
      value : "false"
    }
  ]
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


