variable "region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-2"
}

variable "target_account_id" {
  description = "Target AWS account ID."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = can(regex("^\\d{12}$", var.target_account_id))
    error_message = "target_account_id must be a 12-digit AWS account ID."
  }
}

variable "source_account_id" {
  description = "Source AWS account ID used for temporary DNS migration role trust."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = can(regex("^\\d{12}$", var.source_account_id))
    error_message = "source_account_id must be a 12-digit AWS account ID."
  }
}

variable "repo_full_name" {
  description = "GitHub repository full name, for example org/repository."
  type        = string
}

variable "environment_name" {
  description = "GitHub environment name allowed to assume the provisioner role."
  type        = string
  default     = "prd"
}

variable "tf_state_bucket_name" {
  description = "S3 bucket name for Terraform state."
  type        = string
}

variable "tf_state_prefix" {
  description = "S3 prefix for Terraform state."
  type        = string
  default     = "ses-domain-forwarding"
}

variable "target_role_name" {
  description = "Target-account role assumed by GitHub Actions via OIDC."
  type        = string
  default     = "GitHubSesForwardingProvisionerRole"
}

variable "github_oidc_thumbprints" {
  description = "Thumbprints for token.actions.githubusercontent.com."
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "source_dns_role_name" {
  description = "Source-account DNS role that the target provisioner may assume."
  type        = string
  default     = "GitHubSesForwardingSourceDnsRole"
}

variable "project_name" {
  description = "Project tag value used for bootstrap resources."
  type        = string
  default     = "ses-domain-forwarding"
}
