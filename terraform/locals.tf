locals {
  environment = terraform.workspace
  name        = "${var.project}-${local.environment}"

  site_domain = var.enable_dns ? var.domain_name : module.cdn.domain_name

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repository  = "terraform-aws-emulator"
  }
}
