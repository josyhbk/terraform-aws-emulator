output "certificate_arn" {
  description = "Certificate ARN. Usable by CloudFront only once status is ISSUED."
  value       = aws_acm_certificate.this.arn
}

output "status" {
  description = "Certificate status: PENDING_VALIDATION until the validation records resolve, then ISSUED."
  value       = aws_acm_certificate.this.status
}

output "domain_name" {
  description = "Domain the certificate is for."
  value       = aws_acm_certificate.this.domain_name
}

output "zone_name" {
  description = "Hosted zone for the validation records and the site record."
  value       = var.zone_name

  # Ties the output to the certificate, so `apply -target=module.dns_acm`
  # writes it too. Outputs that only pass a variable through are skipped.
  depends_on = [aws_acm_certificate.this]
}

output "validation_records" {
  description = "CNAME records to publish in the zone that owns the domain."
  value = distinct([
    for o in aws_acm_certificate.this.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ])
}
