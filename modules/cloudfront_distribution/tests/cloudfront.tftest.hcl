# Plan-only tests with a mocked provider: no AWS, no emulator.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  name = "test"
}

run "default_certificate" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].cloudfront_default_certificate
    error_message = "without a certificate the distribution should use *.cloudfront.net"
  }
  assert {
    condition     = aws_cloudfront_origin_access_control.this.name == "test-site-123456789012"
    error_message = "bucket name should end in the account id"
  }
}

run "custom_domain" {
  command = plan

  variables {
    aliases             = ["www.example.com"]
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/test"
  }

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].ssl_support_method == "sni-only"
    error_message = "custom domains should use SNI"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "custom domains should require TLS 1.2"
  }
}

run "alias_needs_certificate" {
  command = plan

  variables {
    aliases = ["www.example.com"]
  }

  expect_failures = [var.aliases]
}
