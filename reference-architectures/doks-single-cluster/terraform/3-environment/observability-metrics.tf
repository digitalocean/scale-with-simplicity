# This data source retrieves the default metrics credentials for DigitalOcean managed databases.
# These credentials are used to access the metrics endpoints of the databases.
data "digitalocean_database_metrics_credentials" "default" {}

# This resource creates a ServiceMonitor for the NGINX Ingress Controller.
# A ServiceMonitor is a custom resource defined by the Prometheus Operator, which declaratively specifies
# how groups of services should be monitored. This ensures that Prometheus will scrape metrics
# from the ingress controller, providing visibility into ingress traffic and performance.
# This will be removed once Cilium Ingress is supported and provides its own ServiceMonitor.
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

### AdService (PostgreSQL) Observability ###

# Retrieves the details of the managed PostgreSQL database cluster for the AdService.
# This is needed to get connection details like the host, port, and credentials.
data "digitalocean_database_cluster" "adservice" {
  name = "${var.name_prefix}-adservice-pg"
}

# Retrieves the CA certificate for the PostgreSQL database cluster.
# This is required for clients to establish a secure, encrypted connection to the database.
data "digitalocean_database_ca" "adservice" {
  cluster_id = data.digitalocean_database_cluster.adservice.id
}

# Creates a Kubernetes secret to store all necessary credentials and certificates for the AdService database.
# This includes the database password, metrics credentials, and the CA certificate.
# The demo application and the Prometheus exporter will mount this secret to connect to the database.
resource "kubernetes_secret_v1" "adservice_database" {
  metadata {
    name      = "adservice-database"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
  }
  data = {
    ca-cert           = data.digitalocean_database_ca.adservice.certificate
    metrics-password  = data.digitalocean_database_metrics_credentials.default.password
    metrics-username  = data.digitalocean_database_metrics_credentials.default.username
    postgres-password = data.digitalocean_database_cluster.adservice.password
    postgres-username = data.digitalocean_database_cluster.adservice.user
  }
  type = "Opaque"
}

# Creates a Kubernetes ConfigMap to store non-sensitive configuration details for the AdService database.
# This includes the database host, name, port, and SSL mode.
# The application can mount this ConfigMap to get its database connection configuration.
resource "kubernetes_config_map_v1" "adservice_database_configuration" {
  metadata {
    name      = "adservice-database-configuration"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
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

# Creates a ScrapeConfig for the AdService's PostgreSQL database.
# ScrapeConfig is a custom resource that allows for more detailed and advanced scrape configurations
# than a ServiceMonitor. Here, it's used to configure Prometheus to scrape the database's metrics endpoint 
# of the managed PostgreSQL database setup in the first stack.
resource "kubernetes_manifest" "adservice_database_scrape_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "ScrapeConfig"
    metadata = {
      name      = "adservice-database"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
      labels = {
        # Label used to discover ScrapeConfigs matching the name of helm_release
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      jobName = "adservice-database"
      scheme  = "HTTPS"
      tlsConfig = {
        ca = {
          secret = {
            name = "adservice-database"
            key  = "ca-cert"
          }
        }
      }
      metricsPath    = "/metrics"
      scrapeInterval = "30s"
      staticConfigs = [
        {
          targets = [
            split("/", data.digitalocean_database_cluster.adservice.metrics_endpoints[0])[2]
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

# Deploys the Prometheus PostgreSQL Exporter using its Helm chart.
# This exporter connects to the PostgreSQL database, runs queries to collect metrics,
# and exposes them in a format that Prometheus can understand and scrape.
resource "helm_release" "postgres_exporter" {
  name       = "postgres-exporter-adservice"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-postgres-exporter"
  # Installing in default as this is specific to the demo app, similar to the ScrapeConfigs
  namespace = kubernetes_namespace_v1.demo.metadata[0].name

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
      interval      = "30s"
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

### CartService (Valkey) Observability ###

# Retrieves the details of the managed Valkey database cluster for the CartService.
data "digitalocean_database_cluster" "cartservice" {
  name = "${var.name_prefix}-cartservice-valkey"
}

# Retrieves the CA certificate for the Valkey database cluster.
data "digitalocean_database_ca" "cartservice" {
  cluster_id = data.digitalocean_database_cluster.cartservice.id
}

# Creates a Kubernetes secret to store credentials and connection info for the CartService's Valkey database.
resource "kubernetes_secret_v1" "cart_database" {
  metadata {
    name      = "cartservice-database"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
  }
  data = {
    ca-cert = data.digitalocean_database_ca.cartservice.certificate
    # camelCase to match what is expected by helm chart
    connectionString = data.digitalocean_database_cluster.cartservice.private_uri
    redis-password   = data.digitalocean_database_cluster.cartservice.password
    redis-username   = data.digitalocean_database_cluster.cartservice.user
    metrics-password = data.digitalocean_database_metrics_credentials.default.password
    metrics-username = data.digitalocean_database_metrics_credentials.default.username
  }
  type = "Opaque"
}

# Creates a ScrapeConfig for the CartService's Valkey database, similar to the one for PostgreSQL.
# This configures Prometheus to scrape metrics from the Valkey database's metrics endpoint.
resource "kubernetes_manifest" "cartservice_database_scrape_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "ScrapeConfig"
    metadata = {
      name      = "cartservice-database"
      namespace = kubernetes_namespace_v1.demo.metadata[0].name
      labels = {
        # Label used to discover ScrapeConfigs matching the name of helm_release
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      jobName = "cartservice-database"
      scheme  = "HTTPS"
      tlsConfig = {
        ca = {
          secret = {
            name = "cartservice-database"
            key  = "ca-cert"
          }
        }
      }
      metricsPath    = "/metrics"
      scrapeInterval = "30s"
      staticConfigs = [
        {
          targets = [
            split("/", data.digitalocean_database_cluster.cartservice.metrics_endpoints[0])[2]
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

# Deploys the Prometheus Redis Exporter using its Helm chart.
# This exporter connects to the Valkey (Redis-compatible) database and exposes its metrics for Prometheus.
resource "helm_release" "redis_exporter_cartservice" {
  name       = "redis-exporter-cartservice"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-redis-exporter"
  namespace  = kubernetes_namespace_v1.demo.metadata[0].name

  values = [
    yamlencode({
      fullnameOverride = "redis-exporter-cartservice"
      redisAddress     = "rediss://${data.digitalocean_database_cluster.cartservice.private_host}:${data.digitalocean_database_cluster.cartservice.port}"
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
        enabled = true
        # Unable to get TLS Verification working, not sure if its the way the SSL certs are issue with just a wildcard SAN
        skipTlsVerification = true
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



