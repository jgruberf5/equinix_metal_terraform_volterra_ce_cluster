terraform {
  required_providers {
    metal = {
      source = "equinix/metal"
      # version = "1.0.0"
    }
    volterra = {
      source = "volterraedge/volterra"
    }
  }
}

# Configure the Equinix Metal Provider.
provider "metal" {
  auth_token = var.metal_auth_token
}

provider "volterra" {
  url          = "https://${var.volterra_tenant}.console.ves.volterra.io/api"
}
