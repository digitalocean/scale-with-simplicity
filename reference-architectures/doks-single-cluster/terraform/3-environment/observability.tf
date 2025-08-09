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

# used by the demo app
resource "kubernetes_secret_v1" "adservice_database" {
  metadata {
    name      = "adservice-database"
    namespace = "default"
  }
  data = {
    ca-cert = data.digitalocean_database_ca.adservice.certificate
    metrics-password = data.digitalocean_database_metrics_credentials.default.password
    metrics-username = data.digitalocean_database_metrics_credentials.default.username
    postgres-password = data.digitalocean_database_cluster.adservice.password
    postgres-username = data.digitalocean_database_cluster.adservice.user
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
            key  = "ca-cert"
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
          key  = "metrics-username"
        }
        password = {
          name = "adservice-database"
          key  = "metrics-password"
        }
      }
    }
  }
}

resource "helm_release" "postgres_exporter" {
  name       = "postgres-exporter-adservice"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-postgres-exporter"
  # Installing in default as this is specific to the demo app, similar to the ScrapeConfigs
  namespace  = "default"

  # Pass the YAML produced from the map above
  values = [yamlencode({
    fullnameOverride = "postgres-exporter-adservice"

    rbac = {
      create = true
    }
    serviceAccount = {
      create = true
    }

    config = {
      extraArgs = [
        # Enabled to get uptime stats
        "--collector.postmaster",
        # Disable as doadmin doesn't have superuser perms needed to get wal metrics.
        "--no-collector.wal"
      ]
      datasource = {
        host     = data.digitalocean_database_cluster.adservice.private_host
        port     = tostring(data.digitalocean_database_cluster.adservice.port)
        database = data.digitalocean_database_cluster.adservice.database
        sslmode  = "require"
        userSecret = {
          name = kubernetes_secret_v1.adservice_database.metadata[0].name
          key  = "postgres-username"
        }
        passwordSecret = {
          name = kubernetes_secret_v1.adservice_database.metadata[0].name
          key  = "postgres-password"
        }
        extraParams = "sslrootcert=/etc/postgres-ca/ca.crt"
      }
    }


    extraVolumes = [
      {
        name = "do-pg-ca"
        secret = {
          secretName = "adservice-database"
          items = [
            {
              key  = "ca-cert"
              path = "ca.crt"
            }
          ]
        }
      }
    ]

    extraVolumeMounts = [
      {
        name      = "do-pg-ca"
        mountPath = "/etc/postgres-ca"
        readOnly  = true
      }
    ]

    serviceMonitor = {
      enabled = true
      labels = {
        release = "kube-prometheus-stack"
      }
      interval     = "30s"
      scrapeTimeout = "10s"
    }

    resources = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }
  })]
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
    ca-cert = data.digitalocean_database_ca.cartservice.certificate
    # camelCase to match what is expected by helm chart
    connectionString = data.digitalocean_database_cluster.cartservice.private_uri
    redis-password = data.digitalocean_database_cluster.cartservice.password
    redis-username = data.digitalocean_database_cluster.cartservice.user
    metrics-password = data.digitalocean_database_metrics_credentials.default.password
    metrics-username = data.digitalocean_database_metrics_credentials.default.username
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
            key  = "ca-cert"
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
          key  = "metrics-username"
        }
        password = {
          name = "cartservice-database"
          key  = "metrics-password"
        }
      }
    }
  }
}

resource "helm_release" "redis_exporter_cartservice" {
  name       = "redis-exporter-cartservice"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-redis-exporter"
  namespace  = "default"

  values = [
    yamlencode({
      fullnameOverride = "redis-exporter-cartservice"
      redisAddress = "rediss://${data.digitalocean_database_cluster.cartservice.private_host}:${data.digitalocean_database_cluster.cartservice.port}"
      env = [
        {
          name = "REDIS_USER"
          valueFrom = {
            secretKeyRef = {
              name = "cartservice-database"
              key  = "redis-username"
            }
          }
        },
        {
          name = "REDIS_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              name = "cartservice-database"
              key  = "redis-password"
            }
          }
        }
      ]

      redisTlsConfig = {
        enabled              = true
        # Unable to get TLS Verification working, not sure if its the way the SSL certs are issue with just a wildcard SAN
        skipTlsVerification  = true
        caCertFile = {
          secret = {
            name = "cartservice-database"
            key  = "ca-cert"
          }
        }
      }

      serviceMonitor = {
        enabled       = true
        namespace     = "default"
        interval      = "30s"
        scrapeTimeout = "10s"
        labels        = { release = "kube-prometheus-stack" }
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
    })
  ]
}



