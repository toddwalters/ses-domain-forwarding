variable "source_account_id" {
  description = "Source AWS account ID."
  type        = string
  default     = null
  nullable    = true
}

variable "target_account_id" {
  description = "Target AWS account ID."
  type        = string
  default     = null
  nullable    = true
}

variable "target_role_name" {
  description = "Target-account role allowed to assume this source DNS role."
  type        = string
  default     = "GitHubSesForwardingProvisionerRole"
}

variable "source_dns_role_name" {
  description = "Source-account DNS role name."
  type        = string
  default     = "GitHubSesForwardingSourceDnsRole"
}

variable "source_authoritative_zone_id" {
  description = "Source hosted zone ID used during migration."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Project tag value used for bootstrap resources."
  type        = string
  default     = "ses-domain-forwarding"
}
