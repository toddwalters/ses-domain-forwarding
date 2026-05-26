locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Environment = var.environment_name
  }

  migration_overrides = {
    for domain_name, config in var.migration_overrides : domain_name => {
      create_source_verification_records = config.create_source_verification_records
      source_authoritative_zone_id       = coalesce(config.source_authoritative_zone_id, var.source_authoritative_zone_id)
      existing_ses_verification_tokens   = config.existing_ses_verification_tokens
    }
  }

  domains = {
    for domain_name, config in var.domain_definitions : domain_name => {
      enabled              = config.enabled
      receipt_rule_enabled = config.receipt_rule_enabled

      source_dns = {
        create_verification_records      = try(local.migration_overrides[domain_name].create_source_verification_records, false)
        authoritative_zone_id            = try(local.migration_overrides[domain_name].source_authoritative_zone_id, var.source_authoritative_zone_id)
        existing_ses_verification_tokens = try(local.migration_overrides[domain_name].existing_ses_verification_tokens, [])
      }

      extra_records = {
        for record_name, record in config.preserved_records : record_name => {
          name    = record.label == "@" ? domain_name : "${record.label}.${domain_name}"
          type    = record.type
          ttl     = record.ttl
          records = record.records
        }
      }

      forwarding = {
        fromEmail      = "${config.forwarding.from_local_part}@${domain_name}"
        subjectPrefix  = config.forwarding.subject_prefix
        emailKeyPrefix = config.forwarding.s3_object_prefix
        destinations   = length(config.forwarding.destinations) > 0 ? config.forwarding.destinations : var.default_forwarding_destinations
        forwardMapping = merge(
          {
            for recipient in config.forwarding.explicit_recipients :
            "${recipient}@${domain_name}" => (length(config.forwarding.destinations) > 0 ? config.forwarding.destinations : var.default_forwarding_destinations)
          },
          config.forwarding.catch_all ? {
            "@${domain_name}" = (length(config.forwarding.destinations) > 0 ? config.forwarding.destinations : var.default_forwarding_destinations)
          } : {},
          contains(config.forwarding.explicit_recipients, "info") ? {
            "info" = (length(config.forwarding.destinations) > 0 ? config.forwarding.destinations : var.default_forwarding_destinations)
          } : {}
        )
      }
    }
  }

  enabled_domains = {
    for domain_name, config in local.domains : domain_name => config
    if config.enabled
  }

  domain_forwarding_config = {
    domains = {
      for domain, config in local.enabled_domains : domain => config.forwarding
    }
  }
}
