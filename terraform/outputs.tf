output "site_url" {
  description = "Site URL."
  value       = "https://${local.site_domain}"
}

output "api_endpoint" {
  description = "API base URL."
  value       = module.api.api_endpoint
}

output "cdn_domain" {
  description = "CloudFront domain, <id>.cloudfront.net."
  value       = module.cdn.domain_name
}

output "cdn_hosted_zone_id" {
  description = "Zone id for alias records to the distribution."
  value       = module.cdn.hosted_zone_id
}

# These two come through module.dns_acm so the certificate-only apply in
# apply-dns fills them in: a targeted apply skips outputs that do not depend
# on the target.
output "site_domain" {
  description = "Custom domain, null without DNS."
  value       = try(module.dns_acm[0].domain_name, null)
}

output "dns_zone" {
  description = "Hosted zone in the DNS account, null without DNS."
  value       = try(module.dns_acm[0].zone_name, null)
}

output "certificate_arn" {
  description = "ACM certificate, null without DNS."
  value       = try(module.dns_acm[0].certificate_arn, null)
}

output "certificate_validation_records" {
  description = "Records apply-dns publishes in the DNS account."
  value       = try(module.dns_acm[0].validation_records, [])
}
