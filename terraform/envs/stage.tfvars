vpc_cidr            = "10.20.0.0/16"
nat_mode            = "single"
enable_flow_logs    = true
deletion_protection = false
log_retention_days  = 14

enable_dns  = true
dns_zone    = "showcase.example.com"
domain_name = "stage.showcase.example.com"
