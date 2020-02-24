locals {
  availability_zone = lookup(var.provider_settings, "availability_zone", null)
  region            = lookup(var.provider_settings, "region", null)
  ssh_allowed_ips   = lookup(var.provider_settings, "ssh_allowed_ips", [])
  name_prefix       = var.name_prefix

  key_name = lookup(var.provider_settings, "key_name", null)
  key_file = lookup(var.provider_settings, "key_file", null)
  ssh_user = lookup(var.provider_settings, "ssh_user", "ec2-user")
  bastion_host = lookup(var.provider_settings, "bastion_host", null)
}

module "network" {
  source = "../network"

  availability_zone = local.availability_zone
  region            = local.region
  ssh_allowed_ips   = local.ssh_allowed_ips
  name_prefix       = local.name_prefix
}

output "configuration" {
  value = merge({
    cc_username          = var.cc_username
    cc_password          = var.cc_password
    timezone             = var.timezone
    ssh_key_path         = var.ssh_key_path
    mirror               = var.mirror
    use_mirror_images    = var.use_mirror_images
    use_avahi            = var.use_avahi
    domain               = var.domain
    name_prefix          = var.name_prefix
    use_shared_resources = var.use_shared_resources
    testsuite            = var.testsuite

    additional_network = lookup(var.provider_settings, "additional_network", null)

    region            = local.region
    availability_zone = local.availability_zone

    key_name = local.key_name
    key_file = local.key_file
    ssh_user = local.ssh_user
    bastion_host = local.bastion_host
    },
  module.network.configuration)
}