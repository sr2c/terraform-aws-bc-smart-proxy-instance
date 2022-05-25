variable "disable_api_termination" {
  type = bool
  description = "Enable EC2 Instance Termination Protection"
}

variable "domain_name" {
  type = string
  description = "Domain name to use for the instance"
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