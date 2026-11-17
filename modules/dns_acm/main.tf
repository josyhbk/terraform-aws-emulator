# ACM certificate for CloudFront, which only takes certificates from
# us-east-1, hence the aliased provider. The validation records are outputs
# instead of Route 53 resources: the hosted zone lives in a separate DNS
# account, and scripts/terraform.sh apply-dns writes them there.

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
