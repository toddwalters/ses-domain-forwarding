# Production Terraform Environment

This environment composes the reusable SES domain forwarding stack for a live
AWS account, with optional source-account DNS support during domain migrations.

## Safety Defaults

- `activate_receipt_rule_set = true` by default because this environment now
  represents the live post-cutover state.
- Source hosted zone verification records are disabled by default because the
  first migration is complete and source cleanup has already been performed.
- The Route53 registered domain nameserver move is intentionally not modeled in
  this first skeleton. It should be imported and applied only during the cutover
  phase.

## Domain Onboarding Shape

Per-domain authoring is split into:

- `var.domain_definitions` for steady-state domain behavior
- `var.migration_overrides` for temporary source-DNS migration settings

Most new domains should only need one `domain_definitions` entry with:

- `enabled`: whether to manage the domain in this environment
- `receipt_rule_enabled`: whether the per-domain SES receipt rule is enabled
- `preserved_records`: extra DNS records that should exist in the target hosted zone
- `forwarding`:
  - `from_local_part`
  - `subject_prefix`
  - `s3_object_prefix`
  - `destinations`
  - `explicit_recipients`
  - `catch_all`

The environment derives the repetitive details from the steady-state shape:

- fully qualified extra-record names
- `fromEmail`
- catch-all and explicit forwarding mappings
- module inputs for enabled domains only

If a domain is being migrated from another zone or AWS account, add a matching
`migration_overrides` entry only for the temporary source-verification pieces.
For already-cut-over or brand-new domains, `migration_overrides` should usually
stay empty.

## Naming Conventions

- S3 raw-email prefix: `domains/<domain>/`
- Forwarder sender identity: `<from_local_part>@<domain>`
- SES receipt rule name: `<domain-with-dots-replaced-by-dashes>-forwarding`
- Hosted zone comment: `Managed hosted zone for <domain>`

## Monitoring Defaults

- CloudWatch alarms are created for shared forwarder Lambda errors and
  throttles by default.
- The low-invocation alarm is supported but disabled by default until a stable
  expected traffic baseline is chosen.
- `alarm_actions` and `ok_actions` can be set to SNS topic ARNs or other
  supported CloudWatch action targets when you are ready to notify on alarm
  transitions.

## Build Order

1. Build the Lambda package from `../../../lambda/ses-email-forwarder`.
2. Run `terraform init`.
3. Copy `terraform.tfvars.example` to a private `terraform.tfvars` file and set
   your real account, bucket, domain, and forwarding values.
4. Run `terraform plan`. For local runs that should use named AWS profiles,
   pass `-var='target_profile=<your-target-profile>'` and
   `-var='source_profile=<your-source-profile>'`.
5. For migration scenarios that still need temporary source DNS writes, pass
   `-var='source_dns_role_arn=arn:aws:iam::<source-account-id>:role/<source-dns-role-name>'`.
