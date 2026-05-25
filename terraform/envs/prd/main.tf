module "shared_inbound_email" {
  source = "../../modules/ses_inbound_shared"

  providers = {
    aws = aws.target
  }

  account_id                     = var.target_account_id
  region                         = var.primary_region
  bucket_name                    = var.shared_inbound_bucket_name
  lambda_function_name           = var.shared_lambda_function_name
  lambda_package_path            = var.lambda_package_path
  receipt_rule_set_name          = var.receipt_rule_set_name
  activate_receipt_rule_set      = var.activate_receipt_rule_set
  domain_forwarding_config       = local.domain_forwarding_config
  alarm_actions                  = var.alarm_actions
  ok_actions                     = var.ok_actions
  enable_low_invocation_alarm    = var.enable_low_invocation_alarm
  low_invocation_alarm_threshold = var.low_invocation_alarm_threshold
}

module "forwarded_domains" {
  for_each = local.enabled_domains

  source = "../../modules/ses_forwarded_domain"

  providers = {
    aws            = aws.target
    aws.source_dns = aws.source_global
  }

  account_id                              = var.target_account_id
  region                                  = var.primary_region
  domain                                  = each.key
  hosted_zone_comment                     = "Managed hosted zone for ${each.key}"
  receipt_rule_set_name                   = module.shared_inbound_email.receipt_rule_set_name
  receipt_rule_enabled                    = each.value.receipt_rule_enabled
  inbound_bucket_name                     = module.shared_inbound_email.bucket_name
  s3_object_key_prefix                    = each.value.forwarding.emailKeyPrefix
  forwarder_lambda_arn                    = module.shared_inbound_email.lambda_function_arn
  source_authoritative_zone_id            = each.value.source_dns.authoritative_zone_id
  source_existing_ses_verification_tokens = each.value.source_dns.existing_ses_verification_tokens
  create_source_verification_records      = each.value.source_dns.create_verification_records
  extra_records                           = each.value.extra_records
}
