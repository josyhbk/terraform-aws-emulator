# Private S3 bucket served through CloudFront with origin access control.
# The bucket only accepts reads signed by this distribution. No DNS here:
# records live in another account, see modules/dns_acm.

data "aws_caller_identity" "current" {}

locals {
  bucket = "${var.name}-site-${data.aws_caller_identity.current.account_id}"
  custom = var.acm_certificate_arn != null

  # AWS managed policies
  caching_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  security_headers  = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  s3_origin_id      = "site"
}

module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.17"

  bucket     = local.bucket
  versioning = { enabled = true }

  attach_deny_insecure_transport_policy = true
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.read_from_cloudfront.json

  tags = var.tags
}

data "aws_iam_policy_document" "read_from_cloudfront" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.bucket}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = local.bucket
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = var.name
  aliases             = var.aliases
  default_root_object = "index.html"
  price_class         = var.price_class
  http_version        = "http2and3"
  is_ipv6_enabled     = true

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = module.bucket.s3_bucket_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.caching_optimized
    response_headers_policy_id = local.security_headers
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.custom
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = local.custom ? "sni-only" : null
    minimum_protocol_version       = local.custom ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = var.tags
}
