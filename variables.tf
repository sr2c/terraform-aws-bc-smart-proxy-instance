variable "disable_api_termination" {
  type = bool
  description = "Enable EC2 Instance Termination Protection"
}

variable "domain_name" {
  type = string
  description = "Domain name to use for the instance"
}

variable "max_transfer_per_hour" {
  type = string
  default = "6442450944"
  description = "The maximum number of bytes that can be sent out per hour."
}

variable "rfc2136_tsig_key" {
  type = string
}

variable "rfc2136_tsig_secret" {
  type = string
}

variable "rfc2136_nameserver" {
  type = string
}

variable "maxmind_account_id" {
  type = string
}

variable "maxmind_license_key" {
  type = string
}
