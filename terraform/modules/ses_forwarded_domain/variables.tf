variable "account_id" {
  description = "AWS account ID that owns the target SES resources."
  type        = string
}

variable "region" {
  description = "AWS region for SES receiving."
  type        = string
}

variable "domain" {
  description = "Domain name to configure for SES forwarding."
  type        = string
}

variable "hosted_zone_comment" {
  description = "Comment for the target hosted zone."
  type        = string
}

variable "receipt_rule_set_name" {
  description = "SES receipt rule set name."
  type        = string
}

variable "receipt_rule_enabled" {
  description = "Whether the domain receipt rule is enabled."
  type        = bool
  default     = true
}

variable "inbound_bucket_name" {
  description = "Shared inbound S3 bucket name."
  type        = string
}

variable "s3_object_key_prefix" {
  description = "Domain-specific S3 object key prefix."
  type        = string
}

variable "forwarder_lambda_arn" {
  description = "Shared forwarder Lambda ARN."
  type        = string
}

variable "source_authoritative_zone_id" {
  description = "Current source hosted zone ID for temporary verification records."
  type        = string
  default     = null
}

variable "source_existing_ses_verification_tokens" {
  description = "Existing source SES verification TXT values to preserve while adding the target token."
  type        = list(string)
  default     = []
}

variable "create_source_verification_records" {
  description = "Whether to create temporary SES records in the current source hosted zone."
  type        = bool
  default     = false
}

variable "extra_records" {
  description = "Additional DNS records to preserve in the target hosted zone."
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = {}
}
