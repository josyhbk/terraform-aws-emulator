variable "domain_name" {
  description = "Domain the certificate is for."
  type        = string
}

variable "zone_name" {
  description = "Hosted zone the validation records belong in. This module does not manage it, it only reports it."
  type        = string
}

variable "subject_alternative_names" {
  description = "Extra names on the same certificate."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags for the certificate."
  type        = map(string)
  default     = {}
}
