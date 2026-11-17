variable "name" {
  description = "Name prefix for every resource in the VPC."
  type        = string
}

variable "cidr" {
  description = "VPC IPv4 range. Must be a /16, the subnet layout is carved out of it."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a valid IPv4 /16, for example 10.10.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones. Each one gets a public, a private and a data subnet."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 4
    error_message = "Use between 2 and 4 availability zones."
  }
}

variable "nat_mode" {
  description = "single: one NAT gateway for the VPC, cheap, fine outside prod. per_az: one per AZ, so losing an AZ does not cut egress for the others."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be single or per_az."
  }
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to a CloudWatch log group created by this module."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Days to keep flow logs. Must be a CloudWatch Logs retention value (1, 3, 5, 7, 14, 30, 60, 90, ...)."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
