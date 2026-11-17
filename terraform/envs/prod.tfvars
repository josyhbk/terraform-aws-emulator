vpc_cidr            = "10.30.0.0/16"
nat_mode            = "per_az"
enable_flow_logs    = true
deletion_protection = true
log_retention_days  = 90

enable_dns  = true
dns_zone    = "showcase.example.com"
domain_name = "app.showcase.example.com"
