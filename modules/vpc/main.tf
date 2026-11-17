# Three-tier VPC on top of terraform-aws-modules/vpc.
#
# The /16 is split per AZ index i:
#   public   x.i.0/24            load balancers and NAT gateways only
#   private  x.(16 * (i+1)).0/20 workloads, out through NAT
#   data     x.(240 + i).0/24    databases, no route to the internet
#
# S3 and DynamoDB are reached through gateway endpoints, which are free and
# keep that traffic off the NAT gateways.

data "aws_region" "current" {}

locals {
  public_subnets   = [for i, _ in var.azs : cidrsubnet(var.cidr, 8, i)]
  private_subnets  = [for i, _ in var.azs : cidrsubnet(var.cidr, 4, i + 1)]
  database_subnets = [for i, _ in var.azs : cidrsubnet(var.cidr, 8, 240 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.8"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.nat_mode == "single"
  one_nat_gateway_per_az = var.nat_mode == "per_az"

  # The data tier gets its own route table with no default route
  create_database_subnet_route_table = true
  create_database_subnet_group       = true

  # Nothing should use the default security group, so it allows nothing
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = var.enable_flow_logs
  flow_log_traffic_type                           = "ALL"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention_days

  tags = var.tags
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(["s3", "dynamodb"])

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids)

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
