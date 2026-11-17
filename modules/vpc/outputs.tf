output "vpc_id" {
  description = "VPC id."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet ids, one per AZ."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private (workload) subnet ids, one per AZ."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Data subnet ids, one per AZ."
  value       = module.vpc.database_subnets
}

output "database_subnet_group" {
  description = "DB subnet group name over the data subnets."
  value       = module.vpc.database_subnet_group_name
}

output "subnet_cidrs" {
  description = "CIDR blocks per tier."
  value = {
    public   = local.public_subnets
    private  = local.private_subnets
    database = local.database_subnets
  }
}

output "nat_gateway_ids" {
  description = "NAT gateway ids."
  value       = module.vpc.natgw_ids
}

output "gateway_endpoint_prefix_lists" {
  description = "Prefix list id per gateway endpoint, for security group rules."
  value       = { for k, v in aws_vpc_endpoint.gateway : k => v.prefix_list_id }
}

output "flow_logs_log_group" {
  description = "Flow logs log group ARN, null when flow logs are off."
  value       = var.enable_flow_logs ? module.vpc.vpc_flow_log_destination_arn : null
}
