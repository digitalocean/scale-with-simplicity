module "regional_loadbalancer" {
  source   = "./modules/regional_loadbalancer"
  for_each = { for vpc in var.vpcs : vpc.region => vpc }

  name      = "${var.name_prefix}-${each.value.region}"
  region    = each.value.region
  vpc_uuid  = each.value.vpc_uuid
  lb_config = var.regional_lb_config
}

module "global_loadbalancer" {
  source                   = "./modules/global_loadbalancer"
  name_prefix              = var.name_prefix
  target_load_balancer_ids = [for lb in module.regional_loadbalancer : lb.lb_details.id]
  glb_config               = var.global_lb_config
}

module "dns" {
  source     = "./modules/dns"
  count      = var.region_dns_records ? 1 : 0
  domain     = var.global_lb_config.domains[0].name
  region_lbs = [for lb in module.regional_loadbalancer : { ip : lb.lb_details.ip, region : lb.lb_details.region }]
}
