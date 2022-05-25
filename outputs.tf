output "config_bucket_name" {
  value = module.configuration_bucket.bucket_id
}

output "ip_addresses" {
  value = [module.instance.public_ip]
}
