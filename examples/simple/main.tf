terraform {
  required_providers {
    acme = {
      source = "vancluever/acme"
    }
  }
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

module "simple" {
  source                    = "./../.."
  namespace                 = "eg"
  name                      = "smart-proxy"
  config_filename           = "example.conf"
  letsencrypt_email_address = "admin@example.com"
  disable_api_termination   = false
  dns_zone                  = "aws.example.com"
}
