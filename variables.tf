##################################################################################
# version - Terraform version required
##################################################################################
variable "TF_VERSION" {
  default     = "0.13"
  description = "terraform version required for schematics"
}

##################################################################################
# Equinix API Token
##################################################################################
variable "metal_auth_token" {
  default     = ""
  description = "Equinix API Token"
}

##################################################################################
# Equinix Project ID
##################################################################################
variable "metal_project_id" {
  default     = ""
  description = "Equinix Project ID"
}

##################################################################################
# Equinix Facility
##################################################################################
variable "metal_facility" {
  default     = "da11"
  description = "Equinix Facility"
  validation {
    condition = contains(["am", "ch", "da", "fr", "ny", "sv", "sg", "sy", "dc", "at", "hk", "ld", "la", "mr", "pa", "se", "sl", "tr"], substr(var.metal_facility, 0 ,2))
    error_message = "Valid facilities start with (am, ch, da, fr, ny, sv, sg, sy, dc, at, hk, ld, la, mr, pa, se, sl, tr)."
  }
}

##################################################################################
# Equinix Instance Plan
##################################################################################
variable "metal_plan" {
  default     = "c3.small.x86"
  description = "Equinix Instance Plan"
  validation {
    condition = contains(["c3.small.x86", "c3.medium.x86"], var.metal_plan)
    error_message = "Valid plans for site deployment are (c3.small.x86, c3.medium.x86)."
  }
}

##################################################################################
# Equinix Metal Server Count
##################################################################################
variable "metal_server_count" {
  type        = number
  default     = 3
  description = "Equinix metal instance count"
  validation  {
    condition = contains([1,3,4,5,6,7,8], var.metal_server_count)
    error_message = "The variable server_count must be between 1 or between 3 and 8."
  }
}

##################################################################################
# Equinix Metal Server profile SSH key name
##################################################################################
variable "metal_ssh_key_name" {
  type        = string
  default     = ""
  description = "Equinix Metal Server profile SSH key name"
}

##################################################################################
# Volterra Node Count per Metal Server
##################################################################################
variable "metal_ce_count" {
  type        = number
  default     = 3
  description = "Volterra Node Count per Metal Server"
  validation  {
    condition = contains([1,2,3], var.metal_ce_count)
    error_message = "The variable server_count must be between 1 and 3."
  }
}

##################################################################################
# The Volterra tenant (group) name
##################################################################################
variable "volterra_tenant" {
  type        = string
  default     = ""
  description = "The Volterra tenant (group) name"
}

##################################################################################
# The Volterra Site token
##################################################################################
variable "volterra_site_token" {
  type        = string
  default     = ""
  description = "The Volterra Site token"
}

##################################################################################
# The Volterra Site name for this site
##################################################################################
variable "volterra_site_name" {
  type        = string
  default     = ""
  description = "The Volterra Site name for this site"
}

##################################################################################
# The Volterra Fleet label for this site
##################################################################################
variable "volterra_fleet_label" {
  type        = string
  default     = ""
  description = "The Volterra Fleet label for this VPC"
}

##################################################################################
# voltstack - Include voltstack
##################################################################################
variable "volterra_voltstack" {
  type        = bool
  default     = false
  description = "Include voltstack"
}

##################################################################################
# The password for the built-in admin Volterra user
##################################################################################
variable "volterra_admin_password" {
  type        = string
  default     = ""
  description = "The password for the built-in admin Volterra user"
}

##################################################################################
# Use SSL tunnels to connect to Volterra
##################################################################################
variable "volterra_ssl_tunnels" {
  type        = bool
  default     = false
  description = "Use SSL tunnels to connect to Volterra"
}

##################################################################################
# Use IPSEC tunnels to connect to Volterra
##################################################################################
variable "volterra_ipsec_tunnels" {
  type        = bool
  default     = true
  description = "Use IPSEC tunnels to connect to Volterra"
}

##################################################################################
# Volterra CE Download URL
##################################################################################
variable "volterra_download_url" {
  type = string
  default     = "https://downloads.volterra.io/releases/images/2021-03-01/centos-7.2009.5-202103011045.qcow2"
  description = "Volterra CE Download URL"
}

##################################################################################
# Volterra CE Download MD5 Sum
##################################################################################
variable "volterra_download_md5" {
  type = string
  default     = "d7e5d6a2c57c6f5b348b6e22faf89233"
  description = "Volterra CE Download MD5 Sum"
}

##################################################################################
# Volterra CE External Subnet CIDR
##################################################################################
variable "volterra_external_cidr" {
  type = string
  default     = "192.168.122.0/24"
  description = "Volterra CE External Subnet CIDR"
}

##################################################################################
# Volterra CE Internal Subnet CIDR
##################################################################################
variable "volterra_internal_cidr" {
  type = string
  default     = "192.168.180.0/24"
  description = "Volterra CE Internal Subnet CIDR"
}

##################################################################################
# Number of internal hosts to support with DHCP
##################################################################################
variable "volterra_internal_dhcp_hosts" {
  type = number
  default     = 100
  description = "Number of internal hosts to support with DHCP"
}

##################################################################################
# Volterra CE Reachable Subnet CIDRs
##################################################################################
variable "volterra_reachable_networks" {
  type        = list(string)
  default     = []
  description = "Volterra CE Reachable Subnet CIDRs"
}

##################################################################################
# Volterra CE Reachable Subnet CIDRs Next Hop Gateway Address
##################################################################################
variable "volterra_reachable_networks_gateway" {
  type        = string
  default     = ""
  description = "Volterra CE Reachable Subnet CIDRs Next Hop Gateway Address"
}