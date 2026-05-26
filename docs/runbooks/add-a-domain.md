# Add A Domain

Use this runbook when the shared SES forwarding stack already exists and you
want to onboard one more domain.

## Choose The Right Path

There are two common cases:

1. **Brand-new domain in the target account**
   - no source DNS writes needed
   - no source verification token preservation needed
2. **Migration from another DNS zone or AWS account**
   - may need temporary source verification records
   - may need cutover sequencing and source cleanup

If you are migrating, also follow
[domain-migration-checklist.md](domain-migration-checklist.md).

## Update `terraform.tfvars`

Add one entry under `domain_definitions`.

### Brand-new domain example

```hcl
domain_definitions = {
  "example.com" = {
    enabled              = true
    receipt_rule_enabled = true

    source_dns = {
      create_verification_records      = false
      authoritative_zone_id            = null
      existing_ses_verification_tokens = []
    }

    preserved_records = {}

    forwarding = {
      from_local_part     = "noreply"
      subject_prefix      = ""
      s3_object_prefix    = "domains/example.com/"
      destinations        = ["ops@example.net"]
      explicit_recipients = ["info", "abuse"]
      catch_all           = true
    }
  }
}
```

### Migration-only fields

Only use these when the domain is still being moved from another setup:

- `source_dns.create_verification_records`
- `source_dns.authoritative_zone_id`
- `source_dns.existing_ses_verification_tokens`

For steady-state domains, keep them disabled or empty.

## Decide The Routing Model

For each domain, decide:

- whether catch-all forwarding should be enabled
- which local parts need explicit handling
- whether all forwarded mail uses one destination list or different ones
- what sender rewrite local part should be used

Recommended starting point:

- use catch-all only when you truly want all unknown recipients forwarded
- keep explicit recipients small and intentional
- use one domain-specific S3 prefix per domain

## Validate Before Apply

```bash
cd lambda/ses-email-forwarder
npm test
npm run build

cd ../../terraform/envs/prd
terraform validate
terraform plan -refresh=false -input=false -var-file=terraform.tfvars
```

## Apply And Verify

1. Run `10-terraform-plan`
2. Review the domain-specific resources:
   - SES identity
   - DKIM records
   - hosted zone records
   - receipt rule
3. Run `20-terraform-apply`
4. Run `18-post-cutover-smoke-test`

## Expected New Resources

For each added domain, the shared platform remains shared, but Terraform should
add:

- a hosted zone
- SES identity and DKIM records
- MX record
- any preserved DNS records you declared
- one per-domain SES receipt rule inside the shared rule set

## Things To Double-Check

- the domain has the right forwarding destinations
- `catch_all` matches the intended behavior
- the S3 prefix matches the domain
- migration-only source DNS fields are not left on for steady-state domains
