# --- Database Log Sink Configuration ---
# Forwards logs from managed databases to Loki via rsyslog.
# Traffic is unencrypted but stays within the private VPC network.
# These resources are in Stack 3 to ensure DNS records for the log sink
# NLB have propagated before the databases attempt to connect.

# Rsyslog logsink for AdService PostgreSQL database
# Note: Sink names have a ~24 character limit
resource "digitalocean_database_logsink_rsyslog" "adservice" {
  cluster_id = data.digitalocean_database_cluster.adservice.id
  name       = "loki-adservice-pg"
  server     = var.log_sink_fqdn
  port       = 514
  tls        = false
  format     = "rfc5424"
}

# Rsyslog logsink for CartService Valkey database
# Note: Sink names have a ~24 character limit
resource "digitalocean_database_logsink_rsyslog" "cartservice" {
  cluster_id = data.digitalocean_database_cluster.cartservice.id
  name       = "loki-cartservice-valkey"
  server     = var.log_sink_fqdn
  port       = 514
  tls        = false
  format     = "rfc5424"
}
