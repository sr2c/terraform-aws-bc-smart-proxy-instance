resource "tls_private_key" "reg_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_private_key.private_key_pem
  email_address   = "admin@${trimsuffix(var.domain_name, ".")}"
}

resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "req" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.cert_private_key.private_key_pem
  subject {
    common_name = "*.${trimsuffix(var.domain_name, ".")}"
  }
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  certificate_request_pem   = tls_cert_request.req.cert_request_pem

  dns_challenge {
    provider = "rfc2136"
    config = {
      RFC2136_NAMESERVER = var.rfc2136_nameserver
      RFC2136_TSIG_KEY = var.rfc2136_tsig_key
      RFC2136_TSIG_SECRET = var.rfc2136_tsig_secret
    }
  }
}
