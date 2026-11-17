# A static site on CloudFront calling a small items API: API Gateway, a
# Lambda in the VPC's private subnets, and DynamoDB reached through the VPC's
# gateway endpoint, so the function never needs the NAT gateway.

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../modules/vpc"

  name             = local.name
  cidr             = var.vpc_cidr
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  nat_mode         = var.nat_mode
  enable_flow_logs = var.enable_flow_logs
}

################################################################################
# API
################################################################################

module "items_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 5.5"

  name       = "${local.name}-items"
  hash_key   = "id"
  attributes = [{ name = "id", type = "S" }]

  point_in_time_recovery_enabled = true
  server_side_encryption_enabled = true
  deletion_protection_enabled    = var.deletion_protection
}

resource "aws_security_group" "api" {
  name        = "${local.name}-api"
  description = "API function: HTTPS out to DynamoDB only"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "api_to_dynamodb" {
  security_group_id = aws_security_group.api.id
  description       = "DynamoDB through the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = module.vpc.gateway_endpoint_prefix_lists["dynamodb"]
}

module "api_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.13"

  function_name = "${local.name}-api"
  description   = "Items API"
  handler       = "app.handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 10

  source_path                  = "${path.module}/../app/api"
  trigger_on_package_timestamp = false # rebuild on code changes only, so a clean plan stays clean

  vpc_subnet_ids         = module.vpc.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.api.id]
  attach_network_policy  = true

  tracing_mode                      = "Active"
  attach_tracing_policy             = true
  cloudwatch_logs_retention_in_days = var.log_retention_days

  environment_variables = {
    TABLE = module.items_table.dynamodb_table_id
  }

  attach_policy_statements = true
  policy_statements = {
    items = {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem", "dynamodb:Scan"]
      resources = [module.items_table.dynamodb_table_arn]
    }
  }

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    api = {
      service    = "apigateway"
      source_arn = "${module.api.api_execution_arn}/*/*"
    }
  }
}

module "api" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 6.1"

  name               = local.name
  description        = "Items API"
  protocol_type      = "HTTP"
  create_domain_name = false

  cors_configuration = {
    allow_origins = ["https://${local.site_domain}"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
    max_age       = 300
  }

  stage_access_log_settings = {
    log_group_retention_in_days = var.log_retention_days
  }
  stage_default_route_settings = {
    data_trace_enabled     = false
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }

  routes = {
    "GET /items" = {
      integration = { uri = module.api_function.lambda_function_arn, payload_format_version = "2.0" }
    }
    "POST /items" = {
      integration = { uri = module.api_function.lambda_function_arn, payload_format_version = "2.0" }
    }
  }
}

################################################################################
# Site
################################################################################

module "dns_acm" {
  count  = var.enable_dns ? 1 : 0
  source = "../modules/dns_acm"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = var.domain_name
  zone_name   = var.dns_zone
}

# CloudFront rejects a certificate that is still PENDING_VALIDATION, and a
# failed distribution create is slow to clean up. Stop before that happens and
# point at the command that validates first.
resource "terraform_data" "certificate_issued" {
  count = var.enable_dns ? 1 : 0
  input = module.dns_acm[0].certificate_arn

  lifecycle {
    precondition {
      condition     = module.dns_acm[0].status == "ISSUED"
      error_message = "The certificate for ${var.domain_name} is not issued yet. Run: scripts/terraform.sh ${local.environment} apply-dns"
    }
  }
}

module "cdn" {
  source = "../modules/cloudfront_distribution"

  name                = local.name
  aliases             = var.enable_dns ? [var.domain_name] : []
  acm_certificate_arn = var.enable_dns ? terraform_data.certificate_issued[0].output : null
}

resource "aws_s3_object" "index" {
  bucket       = module.cdn.bucket_id
  key          = "index.html"
  source       = "${path.module}/../app/site/index.html"
  source_hash  = filemd5("${path.module}/../app/site/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "config" {
  bucket        = module.cdn.bucket_id
  key           = "config.js"
  content       = "window.API_URL = ${jsonencode(module.api.api_endpoint)};\n"
  content_type  = "application/javascript"
  cache_control = "no-cache"
}
