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
    "sv" = {
      # Silicon Valley
      "latitude"  = "37.3382",
      "longitude" = "-121.8863"
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
}

data "metal_reserved_ip_block" "ce_external_network" {
  project_id = var.project_id
  ip_address = cidrhost(var.volterra_external_cidr, 1)
}

resource "volterra_token" "volterra_site_token" {
  name        = var.volterra_site_name
  namespace   = "system"
  description = "Site Authorization Token for ${var.volterra_site_name}"
  disable     = false
}

# TODO: add other volterra objects to create for the site here

data "template_file" "user_data" {
  count    = var.volterra_cluster_size
  template = local.template_file
  vars = {
    hostname           = "${var.volterra_site_name}-vce-${count.index}"
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
  }
  depends_on = [volterra_token.volterra_site_token]
}

resource "metal_vlan" "ce_internal_vlan" {
  facility   = var.facility
  project_id = var.project_id
}

resource "metal_device" "ce_instance" {
  count            = var.volterra_cluster_size
  hostname         = "${var.volterra_site_name}-vce-${count.index}"
  project_id       = var.project_id
  facilities       = [var.facility]
  plan             = var.plan
  operating_system = "centos_7"
  billing_cycle    = "hourly"
  ip_address {
    type            = "public_ipv4"
    cidr            = 31
    reservation_ids = [data.metal_reserved_ip_block.ce_external_network.id]
  }
  ip_address {
    type = "private_ipv4"
  }
  user_data = data.template_file.user_data[count.index].rendered
}

resource "metal_device_network_type" "ce_network_type" {
  count     = var.volterra_cluster_size
  device_id = metal_device.ce_instance[count.index].id
  type      = "hybrid"
}

resource "metal_port_vlan_attachment" "ce_internal_vlan" {
  count     = var.volterra_cluster_size
  device_id = metal_device_network_type.ce_network_type[count.index].id
  port_name = "eth1"
  vlan_vnid = metal_vlan.ce_internal_vlan.vxlan
}
