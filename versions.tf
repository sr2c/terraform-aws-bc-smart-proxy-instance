terraform {
  required_version = ">= 1.3.0"
  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = ">= 2.11.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.41.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.4"
    }
  }
}
