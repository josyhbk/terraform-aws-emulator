variable "project" {
  description = "Project name, the prefix for every resource name."
  type        = string
  default     = "showcase"
}

variable "region" {
  description = "Region for everything except the CloudFront certificate."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC range for this environment, a /16 that does not overlap the others."
  type        = string
}

variable "nat_mode" {
  description = "single or per_az, see modules/vpc."
  type        = string
  default     = "single"
}

variable "enable_flow_logs" {
  description = "VPC flow logs to S3."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protect the DynamoDB table from deletes, including terraform destroy."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the API function and access logs."
  type        = number
  default     = 30
}

variable "enable_dns" {
  description = "Serve the site on domain_name. The first apply with this on goes through scripts/terraform.sh apply-dns."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Site domain, inside dns_zone."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_dns || var.domain_name != null
    error_message = "enable_dns needs domain_name."
  }
}

variable "dns_zone" {
  description = "Hosted zone in the DNS account that holds domain_name."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_dns || var.dns_zone != null
    error_message = "enable_dns needs dns_zone."
  }
}
