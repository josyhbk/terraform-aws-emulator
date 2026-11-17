# Plan-only tests with a mocked provider: no AWS, no emulator.

mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  domain_name = "app.example.com"
}

run "dns_validation" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS"
    error_message = "certificates should validate over DNS"
  }
  assert {
    condition     = aws_acm_certificate.this.domain_name == "app.example.com"
    error_message = "certificate should be for the requested domain"
  }
}
