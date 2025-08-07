data "digitalocean_database_metrics_credentials" "default" {}

# nginx-ingress scrape
# To be removed once Cilium Ingress is supported
resource "kubernetes_manifest" "ingress_nginx_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "ingress-nginx-controller"
      namespace = "cluster-services"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "controller"
          "app.kubernetes.io/instance"  = "ingress-nginx"
          "app.kubernetes.io/name"      = "ingress-nginx"
        }
      }
      namespaceSelector = {
        matchNames = ["cluster-services"]
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# AdService Postgres DB
data "digitalocean_database_cluster" "adservice" {
  name                 = "${var.name_prefix}-adservice-pg"
}

data "digitalocean_database_ca" "adservice" {
  cluster_id = data.digitalocean_database_cluster.adservice.id
}

resource "kubernetes_secret_v1" "adservice_database" {
  metadata {
    name      = "adservice-database"
    namespace = "default"
  }
  data = {
    caCert = data.digitalocean_database_ca.adservice.certificate
    password = data.digitalocean_database_metrics_credentials.default.password
    postgres-password = data.digitalocean_database_cluster.adservice.password
    username = data.digitalocean_database_metrics_credentials.default.username
  }
  type = "Opaque"
}

resource "kubernetes_config_map_v1" "adservice_database_configuration" {
  metadata {
    name      = "adservice-database-configuration"
    namespace = "default"
  }
  data = {
    postgres-password = data.digitalocean_database_cluster.adservice.password
    DB_HOST : data.digitalocean_database_cluster.adservice.private_host
    DB_NAME : data.digitalocean_database_cluster.adservice.database
    DB_PORT : data.digitalocean_database_cluster.adservice.port
    DB_SSL_MODE : "require"
    DB_USER : data.digitalocean_database_cluster.adservice.user
  }
}

resource "kubernetes_manifest" "adservice_database_scrape_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "ScrapeConfig"
    metadata = {
      name      = "adservice-database"
      namespace = "default"
      labels = {
        # Label used to discover ScrapeConfigs matching the name of helm_release
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      jobName         = "adservice-database"
      scheme           = "HTTPS"
      tlsConfig = {
        ca = {
          secret = {
            name = "adservice-database"
            key  = "caCert"
          }
        }
      }
      metricsPath     = "/metrics"
      scrapeInterval  = "30s"
      staticConfigs = [
        {
          targets = [
            split("/",  data.digitalocean_database_cluster.adservice.metrics_endpoints[0])[2]
          ]
        }
      ]
      # References to the adservice-database secret to get the username and password to connect to the metrics endpoint
      basicAuth = {
        username = {
          name = "adservice-database"
          key  = "username"
        }
        password = {
          name = "adservice-database"
          key  = "password"
        }
      }
    }
  }
}



# CartService ValKey DB
data "digitalocean_database_cluster" "cartservice" {
  name                 = "${var.name_prefix}-cartservice-valkey"
}

data "digitalocean_database_ca" "cartservice" {
  cluster_id = data.digitalocean_database_cluster.cartservice.id
}

resource "kubernetes_secret_v1" "cart_database" {
  metadata {
    name      = "cartservice-database"
    namespace = "default"
  }
  data = {
    caCert = data.digitalocean_database_ca.cartservice.certificate
    connectionString = data.digitalocean_database_cluster.cartservice.private_uri
    password = data.digitalocean_database_metrics_credentials.default.password
    username = data.digitalocean_database_metrics_credentials.default.username
  }
  type = "Opaque"
}

resource "kubernetes_manifest" "cartservice_database_scrape_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "ScrapeConfig"
    metadata = {
      name      = "cartservice-database"
      namespace = "default"
      labels = {
        # Label used to discover ScrapeConfigs matching the name of helm_release
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      jobName         = "cartservice-database"
      scheme           = "HTTPS"
      tlsConfig = {
        ca = {
          secret = {
            name = "cartservice-database"
            key  = "caCert"
          }
        }
      }
      metricsPath     = "/metrics"
      scrapeInterval  = "30s"
      staticConfigs = [
        {
          targets = [
            split("/",  data.digitalocean_database_cluster.cartservice.metrics_endpoints[0])[2]
          ]
        }
      ]
      # References to the cartservice-database secret to get the username and password to connect to the metrics endpoint
      basicAuth = {
        username = {
          name = "cartservice-database"
          key  = "username"
        }
        password = {
          name = "cartservice-database"
          key  = "password"
        }
      }
    }
  }
}


