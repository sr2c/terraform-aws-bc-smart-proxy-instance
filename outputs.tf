output "config_bucket_name" {
  description = "The name of the S3 bucket used to update the configuration for the smart proxy instance."
  value = module.conf_log.conf_bucket_id
}

output "ip_addresses" {
  description = "The public IP addresses of the smart proxy instance."
  value = [module.instance.public_ip]
}
