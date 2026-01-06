locals {
  vpc_map = {
    for idx, vpc in var.vpcs :
    "vpc-${idx}" => vpc
  }

  # Create a list of all possible VPC pairs for peering
  vpc_indices = range(length(var.vpcs))

  all_pairs = [
    for i in local.vpc_indices : [
      for j in local.vpc_indices : {
        vpc_1_idx = i
        vpc_2_idx = j
        vpc_1_key = "vpc-${i}"
        vpc_2_key = "vpc-${j}"
      } if i < j
    ]
  ]

  # Flatten the nested list
  vpc_pairs_flat = flatten(local.all_pairs)

  # Filter pairs to only include VPCs in different regions
  valid_vpc_pairs = [
    for pair in local.vpc_pairs_flat : {
      vpc_1_key    = pair.vpc_1_key
      vpc_2_key    = pair.vpc_2_key
      pair_key     = "${pair.vpc_1_key}-to-${pair.vpc_2_key}"
      vpc_1_region = local.vpc_map[pair.vpc_1_key].region
      vpc_2_region = local.vpc_map[pair.vpc_2_key].region
    } if local.vpc_map[pair.vpc_1_key].region != local.vpc_map[pair.vpc_2_key].region
  ]

  # Convert to a map for use with for_each
  vpc_peering_map = {
    for pair in local.valid_vpc_pairs : pair.pair_key => pair
  }
}

resource "digitalocean_vpc" "vpc" {
  for_each = local.vpc_map

  name     = "${var.name_prefix}-${each.value.region}"
  region   = each.value.region
  ip_range = each.value.ip_range
  #description = "Auto-created VPC ${each.key} in ${each.value.region}"
}

# Create VPC peering connections dynamically
resource "digitalocean_vpc_peering" "peerings" {
  for_each = local.vpc_peering_map

  name = "peering-${each.value.vpc_1_key}-to-${each.value.vpc_2_key}"
  vpc_ids = [
    digitalocean_vpc.vpc[each.value.vpc_1_key].id,
    digitalocean_vpc.vpc[each.value.vpc_2_key].id
  ]

}