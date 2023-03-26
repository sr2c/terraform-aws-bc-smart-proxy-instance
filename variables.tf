variable "config_filename" {
  type        = string
  description = "Filename of the nginx configuration to install into the smart proxy instance."
}

variable "disable_api_termination" {
  type        = bool
  description = "Enable EC2 Instance Termination Protection"
}

variable "dns_zone" {
  type        = string
  description = "This name must exist as a zone in Route 53. A wildcard DNS record will be created to point at the smart proxy instance, and a wildcard certificate will be created based on this name and used by the smart proxy."
}

variable "letsencrypt_email_address" {
  type = string
}

variable "max_transfer_per_hour" {
  type        = string
  default     = "6442450944"
  description = "The maximum number of bytes that can be sent out per hour."
}
