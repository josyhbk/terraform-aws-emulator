vpc_cidr            = "10.10.0.0/16"
nat_mode            = "single"
enable_flow_logs    = false
deletion_protection = false
log_retention_days  = 7

# dev is served on its cloudfront.net domain
enable_dns = false
