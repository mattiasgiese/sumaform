provider "libvirt" {
  uri = "qemu:///system"
}

module "base" {
  source = "./modules/base"

  cc_username = "UC7"
  cc_password = "11111"
  images = ["opensuse151"]
  mirror = "opensuse.c3sl.ufpr.br"

  use_mirror_images = false

  // optional parameters with defaults below
  // use_avahi = true
  // name_prefix = "" // if you use name_prefix, make sure to update the server_configuration for clients/minions below
  // timezone = "Europe/Berlin"

//  provider_settings = {
//    bridge = null
//    pool = "default"
//    network_name = "default" // change to "" if you change bridge below
//    additional_network = null
//  }
}

module "server" {
  source = "./modules/server"
  base_configuration = module.base.configuration

  name = "server"
  product_version = "uyuni-released"

  // see modules/server/variables.tf for possible values

  // connect_to_additional_network = true
  // if you want to use two networks
}

//module "client" {
//  source = "./modules/client"
//  base_configuration = module.base.configuration
//
//  name = "client"
//  image = "opensuse151"
//  server_configuration = module.server.configuration
//  // see modules/client/variables.tf for possible values
//}

module "minion1" {
  source = "./modules/minion"
  base_configuration = module.base.configuration

  name = "client"
  image = "opensuse151"
  server_configuration = module.server.configuration
  // see modules/client/variables.tf for possible values
}

module "minion" {
  source = "./modules/minion"
  base_configuration = module.base.configuration

  name = "minion"
  image = "opensuse151"
  server_configuration = module.server.configuration
  // see modules/minion/variables.tf for possible values
}
