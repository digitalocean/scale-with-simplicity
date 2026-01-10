# --- Database Log Sink Configuration ---
# Forwards logs from managed databases to Loki via rsyslog over TLS.
# These resources are in Stack 3 to ensure DNS records for the log sink
# NLB have propagated before the databases attempt to connect.

# Read the CA certificate from Kubernetes secret (created by cert-manager in Stack 2)
data "kubernetes_secret_v1" "syslog_ca" {
  metadata {
    name      = "syslog-ca-secret"
    namespace = "cluster-services"
  }
}

# Rsyslog logsink for AdService PostgreSQL database
# Note: Sink names have a ~24 character limit
resource "digitalocean_database_logsink_rsyslog" "adservice" {
  cluster_id = data.digitalocean_database_cluster.adservice.id
  name       = "loki-adservice-pg"
  server     = var.log_sink_fqdn
  port       = 6514
  tls        = true
  format     = "rfc5424"
  ca_cert    = data.kubernetes_secret_v1.syslog_ca.data["tls.crt"]
}

# Rsyslog logsink for CartService Valkey database
# Note: Sink names have a ~24 character limit
resource "digitalocean_database_logsink_rsyslog" "cartservice" {
  cluster_id = data.digitalocean_database_cluster.cartservice.id
  name       = "loki-cartservice-valkey"
  server     = var.log_sink_fqdn
  port       = 6514
  tls        = true
  format     = "rfc5424"
  ca_cert    = data.kubernetes_secret_v1.syslog_ca.data["tls.crt"]
}
