locals {
  final_config = merge(
    var.glb_config,
    {
      target_load_balancer_ids = var.target_load_balancer_ids
    }
  )
}

resource "digitalocean_loadbalancer" "this" {
  name                     = try(local.final_config.name, "${var.name_prefix}-glb")
  type                     = try(local.final_config.type, "GLOBAL")
  target_load_balancer_ids = local.final_config.target_load_balancer_ids

  dynamic "glb_settings" {
    for_each = try(local.final_config.glb_settings != null ? [local.final_config.glb_settings] : [], [])

    content {
      target_protocol = glb_settings.value.target_protocol
      target_port     = glb_settings.value.target_port

      dynamic "cdn" {
        for_each = try(glb_settings.value.cdn != null ? [glb_settings.value.cdn] : [], [])

        content {
          is_enabled = cdn.value.is_enabled
        }
      }
    }
  }

  dynamic "domains" {
    for_each = try(local.final_config.domains, [])

    content {
      name       = domains.value.name
      is_managed = try(domains.value.is_managed, null)
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
}
