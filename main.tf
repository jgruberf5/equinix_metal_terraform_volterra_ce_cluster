# create a random password if we need it
resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

locals {
  # user admin_password if supplied, else set a random password
  admin_password = var.volterra_admin_password == "" ? random_password.admin_password.result : var.volterra_admin_password
  # because someone can't spell in the /etc/vpm/certified-hardware.yaml file in the qcow2 image
  certified_hardware_map = {
    voltstack = ["kvm-volstack-combo", "kvm-multi-nic-voltstack-combo"],
    voltmesh  = ["kvm-voltmesh", "kvm-multi-nic-voltmesh"]
  }
  template_map = {
    voltstack = "${path.module}/volterra_voltstack_ce.yaml",
    voltmesh  = "${path.module}/volterra_voltmesh_ce.yaml"
  }
  plan_map = {
    "c3.small.x86" = {
      "ce_vcpus" = floor(8 / var.metal_ce_count)
      "ce_ram"   = floor(29360113 / var.metal_ce_count)
    },
    "c3.medium.x86" = {
      "ce_vcpus" = floor(24 / var.metal_ce_count),
      "ce_ram"   = floor(62914528 / var.metal_ce_count)
    }
  }
  reserved_ip_quantity_map = {
    "c3.small.x86" = {
      "quantity" = var.metal_server_count > 4 ? 32 : 16
      "cidr"     = 30
    },
    "c3.medium.x86" = {
      "quantity" = var.metal_server_count > 4 ? 32 : 16
      "cidr"     = 30
    }
  }
  facility_location_map = {
    "am" = {
      # Amsterdam
      "latitude"  = "52.3676",
      "longitude" = "4.9041"
    },
    "ch" = {
      # Chicago
      "latitude"  = "41.8781",
      "longitude" = "-87.6297"
    },
    "da" = {
      # Dallas
      "latitude"  = "32.7766",
      "longitude" = "-96.7969"
    },
    "fr" = {
      # Frankfurt
      "latitude"  = "50.1109",
      "longitude" = "8.6821"
    },
    "ny" = {
      # New York
      "latitude"  = "40.7127",
      "longitude" = "-74.0059"
    },
    "sg" = {
      # Singapore
      "latitude"  = "1.3521",
      "longitude" = "103.8198"
    },
    "sy" = {
      # Sydney
      "latitude"  = "-33.8688",
      "longitude" = "151.2093"
    },
    "dc" = {
      # Washington DC
      "latitude"  = "38.9072",
      "longitude" = "-77.0369"
    },
    "at" = {
      # Atlanta
      "latitude"  = "33.7490",
      "longitude" = "-84.3880"
    },
    "hk" = {
      # Hong Kong
      "latitude"  = "22.3193",
      "longitude" = "114.1694"
    },
    "ld" = {
      # London
      "latitude"  = "51.5074",
      "longitude" = "-0.1278"
    },
    "la" = {
      # Los Angeles
      "latitude"  = "34.0522",
      "longitude" = "-118.2437"
    },
    "mr" = {
      # Marseille
      "latitude"  = "43.2965",
      "longitude" = "5.3698"
    },
    "pa" = {
      # Paris
      "latitude"  = "48.8566",
      "longitude" = "2.3522"
    },
    "se" = {
      # Seattle
      "latitude"  = "47.6062",
      "longitude" = "-122.3321"
    },
    "sl" = {
      # Seoul
      "latitude"  = "37.5665",
      "longitude" = "126.9780"
    },
    "sv" = {
      # Silicon Valley
      "latitude"  = "37.3751",
      "longitude" = "-121.9887"
    },
    "tr" = {
      # Toronto
      "latitude"  = "43.6532",
      "longitude" = "-79.3832"
    }
  }
  which_stack                     = var.volterra_voltstack ? "voltstack" : "voltmesh"
  inside_nic                      = var.volterra_voltstack ? "eth0" : "eth1"
  certified_hardware              = element(local.certified_hardware_map[local.which_stack].*, 1)
  template_file                   = file(local.template_map[local.which_stack])
  total_ces                       = var.metal_ce_count * var.metal_server_count
  ce_vcpus                        = lookup(local.plan_map, var.metal_plan).ce_vcpus
  ce_ram                          = lookup(local.plan_map, var.metal_plan).ce_ram
  cidr_subnets                    = metal_reserved_ip_block.ce_external_network.cidr == 28 ? cidrsubnets(metal_reserved_ip_block.ce_external_network.cidr_notation, 2, 2, 2, 2) : cidrsubnets(metal_reserved_ip_block.ce_external_network.cidr_notation, 3, 3, 3, 3, 3, 3, 3, 3, 3)
  cluster_masters                 = var.metal_server_count > 2 ? 3 : 1
  include_dhcp_server             = var.volterra_internal_dhcp_hosts > 0 ? 1 : 0
  static_ce_addresses             = var.volterra_internal_dhcp_hosts > 0 ? 0 : 1
  include_internal_gateway_routes = length(var.volterra_reachable_networks) > 0 ? 1 : 0
}

# Create an Volterra Site Token
# Not using Volterra resource volterra_token - https://github.com/volterraedge/terraform-provider-volterra/issues/67
resource "null_resource" "volterra_site_token" {
  triggers = {
    tenant    = var.volterra_tenant
    site_name = var.volterra_site_name
    # always force update
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    when       = create
    command    = "${path.module}/volterra_site_token.py --action create --site '${self.triggers.site_name}' --tenant '${self.triggers.tenant}'"
    on_failure = fail
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "${path.module}/volterra_site_token.py --action destroy --site '${self.triggers.site_name}' --tenant '${self.triggers.tenant}'"
    on_failure = fail
  }
}

data "local_file" "volterra_site_token" {
  filename   = "${path.module}/${var.volterra_site_name}_site_token.txt"
  depends_on = [null_resource.volterra_site_token]
}

data "volterra_namespace" "system" {
  name = "system"
}

# Registration Accept
resource "null_resource" "site_registration" {
  triggers = {
    site                = var.volterra_site_name,
    tenant              = var.volterra_tenant,
    cluster_masters     = local.cluster_masters,
    size                = var.metal_server_count * var.metal_ce_count,
    token               = data.local_file.volterra_site_token.content,
    allow_ssl_tunnels   = var.volterra_ssl_tunnels ? "true" : "false",
    allow_ipsec_tunnels = var.volterra_ipsec_tunnels ? "true" : "false",
    voltstack           = var.volterra_voltstack ? "true" : "false"
  }
  depends_on = [metal_port_vlan_attachment.ce_internal_vlan]
  provisioner "local-exec" {
    when       = create
    command    = "${path.module}/volterra_site_registration_actions.py --delay 240 --action 'registernodes' --site '${self.triggers.site}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --ssl ${self.triggers.allow_ssl_tunnels} --ipsec ${self.triggers.allow_ipsec_tunnels} --masters ${self.triggers.cluster_masters} --size ${self.triggers.size} --voltstack '${self.triggers.voltstack}'"
    on_failure = fail
  }
  provisioner "local-exec" {
    when       = destroy
    command    = "${path.module}/volterra_site_registration_actions.py --action 'sitedelete' --site '${self.triggers.site}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --voltstack '${self.triggers.voltstack}'"
    on_failure = fail
  }
}

# TODO: add other volterra objects to create for the site here

# Virtual Interface which provides DHCP
resource "volterra_network_interface" "internal_dhcp_server" {
  count     = local.include_dhcp_server
  name      = "${var.volterra_site_name}-internal"
  namespace = "system"
  ethernet_interface {
    device                    = "eth1"
    site_local_inside_network = true
    not_primary               = true
    cluster                   = true
    untagged                  = true
    dhcp_server {
      dhcp_networks {
        network_prefix = var.volterra_internal_cidr
        pool_settings  = "INCLUDE_IP_ADDRESSES_FROM_DHCP_POOLS"
        pools {
          # leave the 0 host for the network and the 1 host for the gateway
          start_ip = cidrhost(var.volterra_internal_cidr, 2)
          # whole range would look like this
          # end_ip   = cidrhost(var.volterra_internal_cidr, pow(2, (32 - tonumber(split("/", var.volterra_internal_cidr)[1])))-2)
          end_ip = cidrhost(var.volterra_internal_cidr, 2 + var.volterra_internal_dhcp_hosts)
        }
        first_address = true
        same_as_dgw   = true
      }
      automatic_from_start = true
    }
  }
}

# Virtual Interface defining static IPs for the CEs
resource "volterra_network_interface" "internal_static" {
  count     = local.static_ce_addresses * (var.metal_server_count * var.metal_ce_count)
  name      = "${var.volterra_site_name}-ce-${count.index + 1}"
  namespace = "system"
  ethernet_interface {
    device                    = "eth1"
    site_local_inside_network = true
    not_primary               = true
    cluster                   = false
    node                      = "${var.volterra_site_name}-ce-${count.index + 1}"
    untagged                  = true
    static_ip {
      node_static_ip {
        ip_address = "${cidrhost(var.volterra_internal_cidr, count.index + 2)}/${split("/", var.volterra_internal_cidr)[1]}"
      }
    }
  }
}

# Virtual Network
resource "volterra_virtual_network" "internal_networks" {
  count                     = local.include_internal_gateway_routes
  name                      = "${var.volterra_site_name}-internal-networks"
  namespace                 = "system"
  description               = "Routes inside ${var.volterra_site_name}"
  site_local_inside_network = true
  static_routes {
    ip_prefixes = var.volterra_reachable_networks
    ip_address  = var.volterra_reachable_networks_gateway
    attrs       = ["ROUTE_ATTR_INSTALL_HOST", "ROUTE_ATTR_INSTALL_FORWARDING"]
  }
}

# Network Connector
resource "volterra_network_connector" "global" {
  name      = "${var.volterra_site_name}-global"
  namespace = "system"
  sli_to_global_dr {
    global_vn {
      name      = "public"
      namespace = "shared"
      tenant    = "ves-io"
    }
  }
  disable_forward_proxy = true
}

# Fleet
resource "volterra_fleet" "fleet_dhcp_servers" {
  count                    = local.include_dhcp_server
  name                     = var.volterra_site_name
  namespace                = "system"
  fleet_label              = var.volterra_fleet_label
  no_bond_devices          = true
  no_dc_cluster_group      = true
  disable_gpu              = true
  logs_streaming_disabled  = true
  default_storage_class    = true
  no_storage_device        = true
  no_storage_interfaces    = true
  no_storage_static_routes = true
  deny_all_usb             = true
  interface_list {
    interfaces {
      name      = "${var.volterra_site_name}-internal"
      namespace = "system"
      tenant    = data.volterra_namespace.system.tenant_name
    }
  }
  network_connectors {
    name      = "${var.volterra_site_name}-global"
    namespace = "system"
    tenant    = data.volterra_namespace.system.tenant_name
  }

  inside_virtual_network {
    name      = "${var.volterra_site_name}-internal-networks"
    namespace = "system"
    tenant    = data.volterra_namespace.system.tenant_name
  }

}

# Fleet
resource "volterra_fleet" "fleet_static_ips" {
  count                    = local.static_ce_addresses
  name                     = var.volterra_site_name
  namespace                = "system"
  fleet_label              = var.volterra_fleet_label
  no_bond_devices          = true
  no_dc_cluster_group      = true
  disable_gpu              = true
  logs_streaming_disabled  = true
  default_storage_class    = true
  no_storage_device        = true
  no_storage_interfaces    = true
  no_storage_static_routes = true
  deny_all_usb             = true
  interface_list {
    dynamic "interfaces" {
      for_each = range(var.metal_server_count * var.metal_ce_count)
      content {
        name      = "${var.volterra_site_name}-ce-${interfaces.key + 1}"
        namespace = "system"
        tenant    = data.volterra_namespace.system.tenant_name
      }
    }
  }
  network_connectors {
    name      = "${var.volterra_site_name}-global"
    namespace = "system"
    tenant    = data.volterra_namespace.system.tenant_name
  }
  inside_virtual_network {
    name      = "${var.volterra_site_name}-internal-networks"
    namespace = "system"
    tenant    = data.volterra_namespace.system.tenant_name
  }
}

# Create all the configuration files for the deployment
resource "random_uuid" "serial_number_seed" {
}

data "template_file" "user_data" {
  count    = var.metal_server_count
  template = local.template_file
  vars = {
    host_index         = count.index + 1
    host_count         = var.metal_server_count
    site_name          = var.volterra_site_name
    admin_password     = local.admin_password
    cluster_name       = var.volterra_site_name
    fleet_label        = var.volterra_fleet_label
    certified_hardware = local.certified_hardware
    latitude           = lookup(local.facility_location_map, substr(var.metal_facility, 0, 2)).latitude
    longitude          = lookup(local.facility_location_map, substr(var.metal_facility, 0, 2)).longitude
    site_token         = data.local_file.volterra_site_token.content
    profile            = var.metal_plan
    inside_nic         = local.inside_nic
    region             = var.metal_facility
    ce_count           = var.metal_ce_count
    vcpus              = local.ce_vcpus
    ram                = local.ce_ram
    serial_prefix      = substr(random_uuid.serial_number_seed.result, 0, -3)
    external_cidr      = var.volterra_external_cidr
    internal_cidr      = var.volterra_internal_cidr
    internal_vlan_id   = metal_vlan.ce_internal_vlan.vxlan
    external_vlan_id   = metal_vlan.ce_external_vlan.vxlan
    ce_download_url    = var.volterra_download_url
    eips_cidr          = local.cidr_subnets[count.index]
  }
}

resource "metal_reserved_ip_block" "ce_external_network" {
  project_id  = var.metal_project_id
  type        = "public_ipv4"
  metro       = substr(var.metal_facility, 0, 2)
  quantity    = lookup(local.reserved_ip_quantity_map, var.metal_plan).quantity
  description = "Volterra Site ${var.volterra_site_name}"
}

data "metal_project_ssh_key" "project_ssh_key" {
  search     = var.metal_ssh_key_name
  project_id = var.metal_project_id
}

# Create the Hypervisor Hosts
resource "metal_device" "ce_instance" {
  count               = var.metal_server_count
  hostname            = "${var.volterra_site_name}-metal-${count.index}"
  project_id          = var.metal_project_id
  facilities          = [var.metal_facility]
  plan                = var.metal_plan
  operating_system    = "centos_7"
  billing_cycle       = "hourly"
  project_ssh_key_ids = [data.metal_project_ssh_key.project_ssh_key.id]
  user_data           = data.template_file.user_data[count.index].rendered
}

# Create routes (EIPs) for CE external NATs
resource "metal_ip_attachment" "external_EIPs" {
  count         = var.metal_server_count
  device_id     = metal_device.ce_instance[count.index].id
  cidr_notation = local.cidr_subnets[count.index]
}

# Provision the switch enviorment for hybrid-bonded mode deployment
resource "metal_device_network_type" "ce_network_type" {
  count     = var.metal_server_count
  device_id = metal_device.ce_instance[count.index].id
  type      = "hybrid"
}

# Create an external VLAN allowed on the bonded ports
resource "metal_vlan" "ce_external_vlan" {
  facility   = var.metal_facility
  project_id = var.metal_project_id
}

# Attach the internal VLAN to the bond0 interface
resource "metal_port_vlan_attachment" "ce_external_vlan" {
  count     = var.metal_server_count
  device_id = metal_device_network_type.ce_network_type[count.index].id
  port_name = "bond0"
  vlan_vnid = metal_vlan.ce_external_vlan.vxlan
}

# Create an internal VLAN allowed on the bonded ports
resource "metal_vlan" "ce_internal_vlan" {
  facility   = var.metal_facility
  project_id = var.metal_project_id
}

# Attach the internal VLAN to the bond0 interface
resource "metal_port_vlan_attachment" "ce_internal_vlan" {
  count     = var.metal_server_count
  device_id = metal_device_network_type.ce_network_type[count.index].id
  port_name = "bond0"
  vlan_vnid = metal_vlan.ce_internal_vlan.vxlan
}
