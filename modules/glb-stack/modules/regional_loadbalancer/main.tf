locals {
  final_config = merge(
    var.lb_config,
    {
      name     = var.name
      region   = var.region
      vpc_uuid = var.vpc_uuid
    }
  )
}

resource "digitalocean_loadbalancer" "this" {
  name     = local.final_config.name
  region   = local.final_config.region
  vpc_uuid = local.final_config.vpc_uuid

  size      = try(local.final_config.size, null)
  size_unit = try(local.final_config.size_unit, null)
  type      = try(local.final_config.type, null)

  droplet_tag                      = try(local.final_config.droplet_tag, null)
  redirect_http_to_https           = try(local.final_config.redirect_http_to_https, null)
  enable_proxy_protocol            = try(local.final_config.enable_proxy_protocol, null)
  enable_backend_keepalive         = try(local.final_config.enable_backend_keepalive, null)
  http_idle_timeout_seconds        = try(local.final_config.http_idle_timeout_seconds, null)
  disable_lets_encrypt_dns_records = try(local.final_config.disable_lets_encrypt_dns_records, null)
  network_stack                    = try(local.final_config.network_stack, null)
  tls_cipher_policy                = try(local.final_config.tls_cipher_policy, null)

  dynamic "forwarding_rule" {
    for_each = try(local.final_config.forwarding_rule != null ? [local.final_config.forwarding_rule] : [], [])
    content {
      entry_port       = forwarding_rule.value.entry_port
      entry_protocol   = forwarding_rule.value.entry_protocol
      target_port      = forwarding_rule.value.target_port
      target_protocol  = forwarding_rule.value.target_protocol
      certificate_name = try(forwarding_rule.value.certificate_name, null)
      tls_passthrough  = try(forwarding_rule.value.tls_passthrough, null)
    }
  }

  dynamic "healthcheck" {
    for_each = try(local.final_config.healthcheck != null ? [local.final_config.healthcheck] : [], [])
    content {
      protocol                 = healthcheck.value.protocol
      port                     = healthcheck.value.port
      path                     = try(healthcheck.value.path, null)
      check_interval_seconds   = try(healthcheck.value.check_interval_seconds, null)
      response_timeout_seconds = try(healthcheck.value.response_timeout_seconds, null)
      healthy_threshold        = try(healthcheck.value.healthy_threshold, null)
      unhealthy_threshold      = try(healthcheck.value.unhealthy_threshold, null)
    }
  }

  dynamic "sticky_sessions" {
    for_each = try(local.final_config.sticky_sessions != null ? [local.final_config.sticky_sessions] : [], [])

    content {
      type               = sticky_sessions.value.type
      cookie_name        = try(sticky_sessions.value.cookie_name, null)
      cookie_ttl_seconds = try(sticky_sessions.value.cookie_ttl_seconds, null)
    }
  }

  dynamic "firewall" {
    for_each = try(local.final_config.firewall != null ? [local.final_config.firewall] : [], [])

    content {
      allow = try(firewall.value.allow, null)
      deny  = try(firewall.value.deny, null)
    }
  }
}
