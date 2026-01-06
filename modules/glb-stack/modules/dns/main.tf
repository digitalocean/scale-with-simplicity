resource "digitalocean_record" "regional_fqdn" {
  for_each = {
    for lb in var.region_lbs : lb.region => lb
  }
  domain = var.domain
  type   = "A"
  name   = each.value.region
  value  = each.value.ip
  ttl    = 300
}
