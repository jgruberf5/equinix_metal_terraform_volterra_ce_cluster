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
# Volterra CE Download URL
##################################################################################
variable "volterra_download_url" {
  default     = "https://downloads.volterra.io/releases/images/2021-03-01/centos-7.2009.5-202103011045.qcow2"
  description = "Volterra CE Download URL"
}

