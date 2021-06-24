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
variable "auth_token" {
  default     = ""
  description = "Equinix API Token"
}

##################################################################################
# Equinix Project ID
##################################################################################
variable "project_id" {
  default     = ""
  description = "Equinix Project ID"
}

##################################################################################
# Equinix Facility
##################################################################################
variable "facility" {
  default     = "dal11"
  description = "Equinix Facility"
}

##################################################################################
# Equinix Instance Plan
##################################################################################
variable "plan" {
  default     = "c3.small.x86"
  description = "Equinix Instance Plan"
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
# The Volterra cluster size
##################################################################################
variable "volterra_cluster_size" {
  type        = number
  default     = 3
  description = "The Volterra cluster size"
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
  default     = "https://downloads.volterra.io/releases/images/2021-03-01/centos-7.2009.5-202103011045.qcow2"
  description = "Volterra CE Download URL"
}

##################################################################################
# Volterra CE External Subnet CIDR
##################################################################################
variable "volterra_external_cidr" {
  default     = ""
  description = "Volterra CE External Subnet CIDR"
}

##################################################################################
# Volterra CE Internal VLAN ID
##################################################################################
variable "volterra_internal_vlan_id" {
  default     = ""
  description = "Volterra CE Internal VLAN ID"
}

##################################################################################
# Volterra CE Internal Subnet CIDR
##################################################################################
variable "volterra_internal_cidr" {
  default     = ""
  description = "Volterra CE Internal Subnet CIDR"
}

##################################################################################
# Volterra CE Reachable Subnet CIDRs
##################################################################################
variable "volterra_reachable_networks" {
  default     = ""
  description = "Volterra CE Reachable Subnet CIDRs"
}
