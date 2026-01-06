# This resource creates a Kubernetes ConfigMap to hold custom Grafana dashboard definitions.
# Grafana can be configured to automatically discover and load dashboards from ConfigMaps.
resource "kubernetes_config_map_v1" "grafana_dashboard_postgres_exporter" {
  metadata {
    name      = "grafana-dashboard-postgres-exporter"
    namespace = "cluster-services"
    labels = {
      # The label `grafana_dashboard = "1"` is used by the Grafana sidecar to discover this ConfigMap.
      grafana_dashboard = "1"
    }
  }
  data = {
    "postgres-exporter.json" = file("${path.module}/dashboards/postgres-exporter.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards_redis_exporter" {
  metadata {
    name      = "grafana-dashboards-redis-exporter"
    namespace = "cluster-services"
    labels = {
      # The label `grafana_dashboard = "1"` is used by the Grafana sidecar to discover this ConfigMap.
      grafana_dashboard = "1"
    }
  }
  data = {
    "redis-exporter.json" = file("${path.module}/dashboards/redis-exporter.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards_telegraf_system_metrics" {
  metadata {
    name      = "grafana-dashboards-telegraf-system-metrics"
    namespace = "cluster-services"
    labels = {
      # The label `grafana_dashboard = "1"` is used by the Grafana sidecar to discover this ConfigMap.
      grafana_dashboard = "1"
    }
  }
  data = {
    "telegraf-system-metrics.json" = file("${path.module}/dashboards/telegraf-system-metrics.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards_cilium_agent" {
  metadata {
    name      = "grafana-dashboards-cilium-agent"
    namespace = "cluster-services"
    labels = {
      # The label `grafana_dashboard = "1"` is used by the Grafana sidecar to discover this ConfigMap.
      grafana_dashboard = "1"
    }
  }
  data = {
    "cilium-agent.json" = file("${path.module}/dashboards/cilium-agent.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboards_envoy_web" {
  metadata {
    name      = "grafana-dashboards-envoy-web"
    namespace = "cluster-services"
    labels = {
      # The label `grafana_dashboard = "1"` is used by the Grafana sidecar to discover this ConfigMap.
      grafana_dashboard = "1"
    }
  }
  data = {
    "envoy-web.json" = file("${path.module}/dashboards/envoy-web.json")
  }
}


resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = "cluster-services"
  }
  data = {
    admin-user     = "admin"
    admin-password = var.grafana_password
  }
  type = "Opaque"
}


# This data source fetches the default values file for the kube-prometheus-stack Helm chart.
# This allows us to use the official recommended base configuration from DigitalOcean's marketplace
# and then apply our specific customizations on top of it.
data "http" "kube_prometheus_stack_values" {
  url = "https://raw.githubusercontent.com/digitalocean/marketplace-kubernetes/master/stacks/kube-prometheus-stack/values.yml"
}

# This resource deploys the kube-prometheus-stack, a comprehensive monitoring solution for Kubernetes.
# It bundles Prometheus for metrics collection, Grafana for visualization, and Alertmanager for alerting.
# We are using the fetched values file as a base and then overriding some settings, such as disabling
# components that are not needed (kubeControllerManager, kubeProxy) and pointing Grafana to our custom dashboards ConfigMap.
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "cluster-services"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "do-block-storage"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    # Size of volume
                    storage = "5Gi"
                  }
                }
              }
            }
          }
          # Specify retention to ensure volume does not fill up
          retention     = "7d"
          retentionSize = "4GiB"
          # Needed in later K8s clusters where Endpoints have been replaced by EndpointSlice
          serviceDiscoveryRole = "EndpointSlice"
        }
      }

      defaultRules = {
        rules = {
          # These run on management cluster
          kubeControllerManager = false
          etcd                  = false
          kubeScheduler         = false
          # kubeProxy replaced by Cilium
          kubeProxy = false
        }
      }

      # These run on management cluster
      kubeControllerManager = {
        enabled = false
      }
      kubeEtcd = {
        enabled = false
      }
      kubeScheduler = {
        enabled = false
      }

      # kubeProxy replaced by Cilium
      kubeProxy = {
        enabled = false
      }

      alertmanager = {
        alertmanagerSpec = {
          # Small demo cluster → 2 replicas; prod best practice is 3+
          replicas = 2
        }
      }

      grafana = {
        admin = {
          existingSecret = "grafana-admin"
        }

        # Add Loki as a data source
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            url       = "http://loki-gateway.cluster-services"
            access    = "proxy"
            isDefault = false
          }
        ]
      }
    })
  ]
}
