variable "target_profile" {
  description = "Optional AWS profile for the target account. Leave null in GitHub Actions."
  type        = string
  default     = null
  nullable    = true
}

variable "source_profile" {
  description = "Optional AWS profile for the source account. Leave null in GitHub Actions."
  type        = string
  default     = null
  nullable    = true
}

variable "source_dns_role_arn" {
  description = "Optional role ARN to assume for temporary source-account DNS verification records."
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

variable "source_account_id" {
  description = "Source AWS account ID."
  type        = string
  default     = null
  nullable    = true
}

variable "primary_region" {
  description = "Primary SES receiving region for the target stack."
  type        = string
  default     = "us-east-2"
}

variable "source_authoritative_zone_id" {
  description = "Optional source hosted zone ID for temporary SES verification records during migration."
  type        = string
  default     = null
  nullable    = true
}

variable "activate_receipt_rule_set" {
  description = "Whether to activate the target SES receipt rule set."
  type        = bool
  default     = true
}

variable "lambda_package_path" {
  description = "Path to the built Lambda zip package."
  type        = string
  default     = "../../../lambda/ses-email-forwarder/dist/ses-email-forwarder.zip"
}

variable "project_name" {
  description = "Project name used for tags and naming defaults."
  type        = string
  default     = "ses-domain-forwarding"
}

variable "environment_name" {
  description = "Environment name used in tags."
  type        = string
  default     = "prd"
}

variable "shared_inbound_bucket_name" {
  description = "Name of the shared S3 bucket that stores raw inbound mail."
  type        = string
}

variable "shared_lambda_function_name" {
  description = "Name of the shared Lambda function that forwards inbound mail."
  type        = string
  default     = "ses-email-forwarder"
}

variable "receipt_rule_set_name" {
  description = "SES receipt rule set name for managed forwarded domains."
  type        = string
  default     = "domain-forwarding"
}

variable "default_forwarding_destinations" {
  description = "Fallback forwarding destinations used when a domain definition omits explicit destinations."
  type        = list(string)
  default     = []
}

variable "global_region" {
  description = "AWS region used for global-like APIs such as Route53 Domains."
  type        = string
  default     = "us-east-1"
}

variable "domain_definitions" {
  description = "Canonical steady-state per-domain forwarding configuration."
  type = map(object({
    enabled              = bool
    receipt_rule_enabled = bool
    preserved_records = map(object({
      label   = string
      type    = string
      ttl     = number
      records = list(string)
    }))
    forwarding = object({
      from_local_part     = string
      subject_prefix      = string
      s3_object_prefix    = string
      destinations        = list(string)
      explicit_recipients = list(string)
      catch_all           = bool
    })
  }))
  default = {}
}

variable "migration_overrides" {
  description = "Optional migration-only per-domain source DNS settings."
  type = map(object({
    create_source_verification_records = bool
    source_authoritative_zone_id       = optional(string)
    existing_ses_verification_tokens   = list(string)
  }))
  default = {}
}

variable "alarm_actions" {
  description = "Optional CloudWatch alarm action ARNs, such as an SNS topic."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Optional CloudWatch OK action ARNs, such as an SNS topic."
  type        = list(string)
  default     = []
}

variable "enable_low_invocation_alarm" {
  description = "Whether to enable the shared forwarder Lambda low-invocation alarm."
  type        = bool
  default     = false
}

variable "low_invocation_alarm_threshold" {
  description = "Minimum expected invocation count within the low-invocation alarm period."
  type        = number
  default     = 1
}
