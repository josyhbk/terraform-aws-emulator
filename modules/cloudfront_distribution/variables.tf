variable "name" {
  description = "Name prefix for the bucket and the distribution."
  type        = string
}

variable "aliases" {
  description = "Custom domain names for the distribution. Needs acm_certificate_arn."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
    error_message = "A custom domain needs acm_certificate_arn, an issued certificate in us-east-1."
  }
}

variable "acm_certificate_arn" {
  description = "Issued ACM certificate in us-east-1 covering the aliases. Null uses the default *.cloudfront.net certificate."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 serves from North America and Europe only."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}
