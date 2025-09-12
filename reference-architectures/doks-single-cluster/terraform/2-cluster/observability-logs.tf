resource "digitalocean_spaces_bucket" "loki_logs" {
  name   = "${var.name_prefix}-loki-logs"
  region = data.digitalocean_kubernetes_cluster.doks_cluster.region
}

resource "digitalocean_spaces_key" "loki_logs" {
  name = "loki-logs"
  grant {
    bucket     = digitalocean_spaces_bucket.loki_logs.name
    permission = "readwrite"
  }
}

# Helm chart does not have a way to reference a secret, so we just inject these API Keys into the pods directly as Env Vars
resource "kubernetes_secret_v1" "loki_logs_spaces_access_key" {
  metadata {
    name      = "loki-logs-spaces-access-key"
    namespace = kubernetes_namespace_v1.cluster_services.metadata[0].name
  }
  data = {
    AWS_ACCESS_KEY_ID = digitalocean_spaces_key.loki_logs.access_key
    AWS_SECRET_ACCESS_KEY = digitalocean_spaces_key.loki_logs.secret_key
  }
  type = "Opaque"
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart = "loki"
  namespace = kubernetes_namespace_v1.cluster_services.metadata[0].name
  values = [
    yamlencode({
      # SimpleScalable strikes a balance between deploying in monolithic mode or deploying each component as a separate microservice.
      # https://grafana.com/docs/loki/latest/get-started/deployment-modes/#simple-scalable
      deploymentMode = "SimpleScalable"

      global = {
        extraEnvFrom = [
          {
            secretRef = {
              name = kubernetes_secret_v1.loki_logs_spaces_access_key.metadata[0].name
            }
          }
        ]
      }

      loki = {
        # Disable auth since single tenant and dedicated to this cluster
        auth_enabled = false

        limits_config = {
          retention_period              = "168h"
        }

        compactor = {
          retention_enabled = true
          delete_request_store = "s3"
        }

        storage = {
          bucketNames = {
            chunks = digitalocean_spaces_bucket.loki_logs.name
            ruler  = digitalocean_spaces_bucket.loki_logs.name
          }
          s3 = {
            endpoint           = "https://${digitalocean_spaces_bucket.loki_logs.region}.digitaloceanspaces.com"
            region             = "us-east-1"
            s3ForcePathStyle   = true
            signatureVersion   = "v4"
            disable_dualstack  = true
          }
        }

        schemaConfig = {
          configs = [
            {
              # Data is just used to determine when the schema was first used.
              from         = "2025-09-12"
              store        = "tsdb"
              object_store = "s3"
              schema       = "v13"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
      }

      chunksCache = {
        # Memory resource/limit defaulting to 9Gb, so tune it down for demo
        resources = {
          requests = {
            memory = "1Gi"
          }
          limits = {
            memory = "1Gi"
          }
        }
      }

    })
  ]
}


resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  namespace  = kubernetes_namespace_v1.cluster_services.metadata[0].name

  values = [
    yamlencode({
      controller = { type = "daemonset" }

      alloy = {
        # Mount host logs for file tailing
        mounts = { varlog = true }

        configMap = {
          content = <<-EOT
            logging { level = "info" }

            // --- LOKI SINK ---
            loki.write "default" {
              endpoint { url = "http://loki-gateway.cluster-services:3100/loki/api/v1/push" }
            }

            // --- FILE-BASED POD LOGS ---
            // Discover all container log files on the node via globbing.
            // On containerd-based clusters, /var/log/containers/*.log symlinks to /var/log/pods/...
            local.file_match "pod_logs" {
              path_targets = [
                { __path__ = "/var/log/containers/*.log" },
              ]
            }

            // Tail the files and ship to Loki
            loki.source.file "pod_logs" {
              targets    = local.file_match.pod_logs.targets
              forward_to = [loki.process.pods.receiver]
            }

            // Add any static labels you want (cluster/env, etc.)
            loki.process "pods" {
              // stage.static_labels { values = { cluster = "doks" } }
              forward_to = [loki.write.default.receiver]
            }

            // --- KUBERNETES EVENTS (API) ---
            loki.source.kubernetes_events "events" {
              forward_to = [loki.process.events.receiver]
            }
            loki.process "events" {
              // stage.static_labels { values = { cluster = "doks" } }
              forward_to = [loki.write.default.receiver]
            }
          EOT
        }
      }
    })
  ]
}

