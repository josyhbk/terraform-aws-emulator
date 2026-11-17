output "bucket_id" {
  description = "Site bucket name. Upload content here."
  value       = module.bucket.s3_bucket_id
}

output "distribution_id" {
  description = "Distribution id, for invalidations."
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "Distribution domain, <id>.cloudfront.net."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "Route 53 zone id for alias records pointing at the distribution."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}
