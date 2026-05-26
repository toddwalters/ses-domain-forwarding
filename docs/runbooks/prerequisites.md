# Prerequisites

Use this checklist to decide whether this repository fits your setup before you
start wiring in real account and domain values.

If it does fit, continue with [quickstart.md](quickstart.md). If you want the
design tradeoffs first, read [architecture-and-security.md](architecture-and-security.md).

## What This Project Is

This repository is for **SES inbound forwarding**, not full mailbox hosting.

It is a good fit if you want to:

- receive inbound email for one or more domains with Amazon SES
- store raw inbound messages in S3
- transform and forward those messages with one shared Lambda
- manage the infrastructure with Terraform

It is not a full email platform with:

- IMAP or POP mailboxes
- per-user mailbox storage
- interactive email clients
- general-purpose outbound email application workflows

## What You Need To Already Have

### AWS

- an AWS account where the shared SES forwarding stack will live
- permission to create or manage:
  - SES identities and receipt rules
  - S3 buckets and lifecycle rules
  - Lambda functions and IAM roles
  - Route53 hosted zones and DNS records
  - CloudWatch alarms and logs
  - SSM parameters

### Domains and DNS

- at least one domain you control
- authority to publish SES verification, DKIM, and MX records
- if migrating an existing domain, authority to update nameservers or DNS in
  the current source location

### GitHub / CI

- a GitHub repository where Actions can run
- permission to configure GitHub environment variables and secrets
- willingness to use AWS OIDC or temporary bootstrap credentials for setup

### Local Tooling

- Terraform
- Node.js and npm
- a shell environment capable of running the validation scripts

## What This Repository Assumes Architecturally

- one shared inbound S3 bucket for all managed domains
- one shared forwarding Lambda for all managed domains
- one shared SES receipt rule set
- one or more domain entries in `domain_definitions`
- per-domain forwarding behavior driven by configuration, not separate code

## What You Must Provide Privately

This repository does **not** expect these values to be committed:

- real AWS account IDs
- real domain names
- hosted zone IDs
- real forwarding destinations
- Terraform state bucket names
- named local AWS profiles
- bootstrap credentials or session tokens

Provide them through:

- a private `terraform.tfvars`
- GitHub environment variables
- GitHub secrets

See [../../terraform/envs/prd/terraform.tfvars.example](../../terraform/envs/prd/terraform.tfvars.example)
for the expected shape.

## Special Case: Domain Migrations

If you are migrating an existing SES domain from another account or DNS zone,
the repository assumes there may be an additional temporary source-DNS step.

That means you may also need:

- a source AWS account ID
- a source hosted zone ID
- a temporary source-account DNS role for migration-time verification records

If you are only onboarding brand-new domains directly in the target account,
that migration path may not be needed.
