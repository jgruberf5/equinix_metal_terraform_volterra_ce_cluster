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
      "ce_count" = 2,
      "ce_vcpus" = 4,
      "ce_ram" = 15728640
    },
    "c3.medium.x86" = {
      "ce_count" = 3,
      "ce_vcpus" = 8,
      "ce_ram" = 20971520
    }
  }
  reserved_ip_quantity_map = {
    "c3.small.x86" = {
      "quantity" = var.server_count > 4 ? 32 : 16
      "cidr" = 30
    },
    "c3.medium.x86" = {
      "quantity" = var.server_count > 4 ? 32 : 16
      "cidr" = 30
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
    "tr" = {
      # Toronto
      "latitude"  = "43.6532",
      "longitude" = "-79.3832"
    }
  }
  which_stack        = var.volterra_voltstack ? "voltstack" : "voltmesh"
  inside_nic         = var.volterra_voltstack ? "eth0" : "eth1"
  certified_hardware = element(local.certified_hardware_map[local.which_stack].*, 1)
  template_file      = file(local.template_map[local.which_stack])
  total_ces = lookup(local.plan_map, var.plan).ce_count * var.server_count
  ce_count = lookup(local.plan_map, var.plan).ce_count
  ce_vcpus = lookup(local.plan_map, var.plan).ce_vcpus
  ce_ram = lookup(local.plan_map, var.plan).ce_ram
  cidr_subnets = metal_reserved_ip_block.ce_external_network.cidr == 28 ? cidrsubnets(metal_reserved_ip_block.ce_external_network.cidr_notation, 2, 2, 2, 2) : cidrsubnets(metal_reserved_ip_block.ce_external_network.cidr_notation, 3, 3, 3, 3, 3, 3, 3, 3, 3)
}

resource "metal_reserved_ip_block" "ce_external_network" {
  project_id = var.project_id
  type = "public_ipv4"
  metro = substr(var.facility, 0, 2)
  quantity = lookup(local.reserved_ip_quantity_map, var.plan).quantity
  description = "Volterra Site ${var.volterra_site_name}"
}


# Create an Volterra Site Token
resource "volterra_token" "volterra_site_token" {
  name        = var.volterra_site_name
  namespace   = "system"
  description = "Site Authorization Token for ${var.volterra_site_name}"
}

# TODO: add other volterra objects to create for the site here


# Create all the configuration files for the deployment
resource "random_uuid" "serial_number_seed" {
}

data "template_file" "user_data" {
  count    = var.server_count
  template = local.template_file
  vars = {
    host_index         = count.index + 1
    host_count         = var.server_count
    site_name          = var.volterra_site_name
    admin_password     = local.admin_password
    cluster_name       = var.volterra_site_name
    fleet_label        = var.volterra_fleet_label
    certified_hardware = local.certified_hardware
    latitude           = lookup(local.facility_location_map, substr(var.facility, 0, 2)).latitude
    longitude          = lookup(local.facility_location_map, substr(var.facility, 0, 2)).longitude
    site_token         = volterra_token.volterra_site_token.id
    profile            = var.plan
    inside_nic         = local.inside_nic
    region             = var.facility
    ce_count           = local.ce_count
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
  depends_on = [volterra_token.volterra_site_token]
}

data "metal_project_ssh_key" "project_ssh_key" {
  search     = "jgruber"
  project_id = var.project_id
}

# Create the Hypervisor Hosts
resource "metal_device" "ce_instance" {
  count            = var.server_count
  hostname         = "${var.volterra_site_name}-metal-${count.index}"
  project_id       = var.project_id
  facilities       = [var.facility]
  plan             = var.plan
  operating_system = "centos_7"
  billing_cycle    = "hourly"
  project_ssh_key_ids = [ data.metal_project_ssh_key.project_ssh_key.id ]
  user_data = data.template_file.user_data[count.index].rendered
}

# Create routes (EIPs) for CE external NATs
resource "metal_ip_attachment" "external_EIPs" {
  count            = var.server_count
  device_id        = metal_device.ce_instance[count.index].id
  cidr_notation    = local.cidr_subnets[count.index]
}

# Provision the switch enviorment for hybrid-bonded mode deployment
resource "metal_device_network_type" "ce_network_type" {
  count     = var.server_count
  device_id = metal_device.ce_instance[count.index].id
  type      = "hybrid"
}

# Create an external VLAN allowed on the bonded ports
resource "metal_vlan" "ce_external_vlan" {
  facility   = var.facility
  project_id = var.project_id
}

# Attach the internal VLAN to the bond0 interface
resource "metal_port_vlan_attachment" "ce_external_vlan" {
  count     = var.server_count
  device_id = metal_device_network_type.ce_network_type[count.index].id
  port_name = "bond0"
  vlan_vnid = metal_vlan.ce_external_vlan.vxlan
}

# Create an internal VLAN allowed on the bonded ports
resource "metal_vlan" "ce_internal_vlan" {
  facility   = var.facility
  project_id = var.project_id
}

# Attach the internal VLAN to the bond0 interface
resource "metal_port_vlan_attachment" "ce_internal_vlan" {
  count     = var.server_count
  device_id = metal_device_network_type.ce_network_type[count.index].id
  port_name = "bond0"
  vlan_vnid = metal_vlan.ce_internal_vlan.vxlan
}

