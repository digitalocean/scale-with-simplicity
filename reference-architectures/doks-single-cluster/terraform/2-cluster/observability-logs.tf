data "digitalocean_spaces_bucket" "loki_logs" {
  name   = "${var.name_prefix}-loki-logs"
  region = data.digitalocean_kubernetes_cluster.doks_cluster.region
}

resource "digitalocean_spaces_key" "loki_logs" {
  name = "loki-logs"
  grant {
    bucket     = data.digitalocean_spaces_bucket.loki_logs.name
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
            chunks = data.digitalocean_spaces_bucket.loki_logs.name
            ruler  = data.digitalocean_spaces_bucket.loki_logs.name
          }
          s3 = {
            endpoint           = "https://${data.digitalocean_spaces_bucket.loki_logs.region}.digitaloceanspaces.com"
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
              from         = "2025-06-01"
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
  recreate_pods = true

  values = [
    yamlencode({
      controller = {
        type = "daemonset"
        volumes = {
          extra = [
            {
              name = "alloy-syslog-tls"
              secret = {
                secretName = "alloy-syslog-tls"
              }
            }
          ]
        }
      }

      alloy = {
        # Tail files from the host
        mounts = {
          varlog = true
          # Mount the TLS certificate for syslog listener
          extra = [
            {
              name      = "alloy-syslog-tls"
              mountPath = "/etc/alloy/certs"
              readOnly  = true
            }
          ]
        }

        # We need the node name to keep only pods scheduled on *this* node.
        extraEnv = [
          {
            name = "HOST_NODE_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName"
              }
            }
          }
        ]

        configMap = {
          content = <<-EOT
            logging { level = "info" }

            // --- LOKI SINK ---
            loki.write "default" {
              endpoint { url = "http://loki-gateway.cluster-services/loki/api/v1/push" }
            }

            // --- DISCOVER PODS (metadata only) ---
            discovery.kubernetes "pods" {
              role = "pod"
            }

            // --- RELABEL: keep only pods on this node, compute file path, and expose labels ---
            discovery.relabel "pod_targets" {
              targets = discovery.kubernetes.pods.targets

              // Keep only pods scheduled on this node
              rule {
                source_labels = ["__meta_kubernetes_pod_node_name"]
                regex         = env("HOST_NODE_NAME")
                action        = "keep"
              }

              // Set the logfile path for container logs on this node
              // /var/log/containers/<pod>_<namespace>_<container>-<id>.log
              rule {
                source_labels = [
                  "__meta_kubernetes_pod_name",
                  "__meta_kubernetes_namespace",
                  "__meta_kubernetes_pod_container_name",
                  "__meta_kubernetes_pod_container_id",
                ]
                separator     = "_"
                regex         = "(.+)_(.+)_(.+)_(?:containerd://|docker://)?([a-f0-9]+).*"
                target_label  = "__path__"
                replacement   = "/var/log/containers/$${1}_$${2}_$${3}-$${4}.log"
                action        = "replace"
              }

              // Promote common k8s identity labels
              rule {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "namespace"
              }
              rule {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "pod"
              }
              rule {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label  = "container"
              }
              rule {
                source_labels = ["__meta_kubernetes_pod_node_name"]
                target_label  = "node"
              }

              // Map all pod labels into Loki labels (e.g., app_kubernetes_io_name, app, etc.)
              rule {
                action = "labelmap"
                regex  = "__meta_kubernetes_pod_label_(.+)"
              }
            }

            // --- FILE-TAILER with enriched targets ---
            loki.source.file "pods" {
              targets    = discovery.relabel.pod_targets.output
              forward_to = [loki.process.pods.receiver]
            }

            // Parse CRI format (timestamps/stream), then forward
            loki.process "pods" {
              stage.cri {}
              forward_to = [loki.write.default.receiver]
            }

            // --- KUBERNETES EVENTS (lightweight via API) ---
            loki.source.kubernetes_events "events" {
              forward_to = [loki.process.events.receiver]
            }
            loki.process "events" {
              forward_to = [loki.write.default.receiver]
            }
            // --- SYSLOG LISTENER for Log Sink with TLS ---
            loki.source.syslog "logsink" {
              listener {
                address = "0.0.0.0:6514"
                protocol = "tcp"
                tls_config {
                  cert_file = "/etc/alloy/certs/tls.crt"
                  key_file  = "/etc/alloy/certs/tls.key"
                }
              }
              forward_to = [loki.write.default.receiver]
            }
          EOT
        }
      }
    })
  ]
  depends_on = [kubernetes_manifest.syslog_server_certificate]
}

# LoadBalancer Service for Log Sink - exposes Alloy's syslog listener to external rsyslog sources
resource "kubernetes_service_v1" "alloy_syslog_nlb" {
  metadata {
    name      = "alloy-syslog-nlb"
    namespace = kubernetes_namespace_v1.cluster_services.metadata[0].name
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = var.log_sink_fqdn
      "service.beta.kubernetes.io/do-loadbalancer-name" = "${var.name_prefix}-syslog-nlb"
      "service.beta.kubernetes.io/do-loadbalancer-network" = "INTERNAL"
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      name        = "syslog-tcp"
      protocol    = "TCP"
      port        = 6514
      target_port = 6514
    }

    selector = {
      "app.kubernetes.io/name" = "alloy"
      "app.kubernetes.io/instance" = "alloy"
    }
  }
}

# Self-signed ClusterIssuer for creating a root CA
resource "kubernetes_manifest" "syslog_ca_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "syslog-ca-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
}

# Root CA Certificate
resource "kubernetes_manifest" "syslog_ca_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "syslog-ca"
      namespace = kubernetes_namespace_v1.cluster_services.metadata[0].name
    }
    spec = {
      isCA       = true
      commonName = "Syslog Log Sink CA"
      secretName = "syslog-ca-secret"
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      issuerRef = {
        name  = kubernetes_manifest.syslog_ca_issuer.manifest.metadata.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }
}

# CA ClusterIssuer using the generated CA
resource "kubernetes_manifest" "syslog_ca_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "syslog-ca-cluster-issuer"
    }
    spec = {
      ca = {
        secretName = kubernetes_manifest.syslog_ca_certificate.manifest.spec.secretName
      }
    }
  }
}

# Server Certificate for Alloy syslog listener
resource "kubernetes_manifest" "syslog_server_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "syslog-server-cert"
      namespace = kubernetes_namespace_v1.cluster_services.metadata[0].name
    }
    spec = {
      secretName = "alloy-syslog-tls"
      issuerRef = {
        name  = kubernetes_manifest.syslog_ca_cluster_issuer.manifest.metadata.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      dnsNames = [
        var.log_sink_fqdn
      ]
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
    }
  }
}



