output "shared_bucket_name" {
  description = "Shared inbound email bucket."
  value       = module.shared_inbound_email.bucket_name
}

output "forwarder_lambda_arn" {
  description = "Shared SES email forwarder Lambda ARN."
  value       = module.shared_inbound_email.lambda_function_arn
}

output "receipt_rule_set_name" {
  description = "Target SES receipt rule set name."
  value       = module.shared_inbound_email.receipt_rule_set_name
}

output "forwarder_alarm_names" {
  description = "CloudWatch alarm names for the shared SES forwarder Lambda."
  value       = module.shared_inbound_email.alarm_names
}

output "domain_hosted_zones" {
  description = "Per-domain target hosted zone details."
  value = {
    for domain, module_instance in module.forwarded_domains : domain => {
      zone_id      = module_instance.hosted_zone_id
      name_servers = module_instance.name_servers
    }
  }
}

output "ses_verification_records" {
  description = "SES verification and DKIM records created for each domain."
  value = {
    for domain, module_instance in module.forwarded_domains : domain => {
      verification_record = module_instance.ses_verification_record
      dkim_records        = module_instance.dkim_records
    }
  }
}

output "domain_plan_summary" {
  description = "Human-readable summary of enabled domains and their forwarding behavior."
  value = {
    for domain, config in local.enabled_domains : domain => {
      receipt_rule_enabled            = config.receipt_rule_enabled
      catch_all_enabled               = contains(keys(config.forwarding.forwardMapping), "@${domain}")
      explicit_recipient_count        = length([for address in keys(config.forwarding.forwardMapping) : address if strcontains(address, "@") && address != "@${domain}"])
      forwarding_destination_count    = length(config.forwarding.destinations)
      forwarding_destinations         = config.forwarding.destinations
      sender_identity                 = config.forwarding.fromEmail
      s3_object_prefix                = config.forwarding.emailKeyPrefix
      extra_record_count              = length(config.extra_records)
      source_dns_verification_enabled = config.source_dns.create_verification_records
      source_dns_token_count          = length(config.source_dns.existing_ses_verification_tokens)
    }
  }
}
