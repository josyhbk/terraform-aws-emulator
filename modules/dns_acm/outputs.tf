output "certificate_arn" {
  description = "Certificate ARN. Usable by CloudFront only once status is ISSUED."
  value       = aws_acm_certificate.this.arn
}

output "status" {
  description = "Certificate status: PENDING_VALIDATION until the validation records resolve, then ISSUED."
  value       = aws_acm_certificate.this.status
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
