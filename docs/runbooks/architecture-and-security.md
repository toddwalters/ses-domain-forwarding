# Architecture And Security Notes

This document explains the opinionated choices in the repository and the trust
boundaries they create.

## Core Architecture

The repository favors one shared inbound stack:

- one SES receipt rule set
- one S3 bucket for raw inbound mail
- one forwarding Lambda
- one SSM configuration document

Each managed domain contributes:

- SES identity
- DKIM records
- hosted zone records
- one receipt rule within the shared rule set

This keeps cost and operational overhead lower than deploying one full stack per
domain.

## Why One Shared Lambda

The Lambda is configuration-driven rather than domain-specific. That makes:

- onboarding more domains mostly data entry
- logging and alarm strategy consistent
- dependency review easier because there is only one forwarding package

The tradeoff is that one Lambda becomes a shared operational surface. Good
logging, alarms, and careful config review matter more in this model.

For day-to-day debugging, use the
[CloudWatch Logs Insights cookbook](cloudwatch-logs-insights-cookbook.md).

## Why One Shared Bucket

Raw mail is stored under domain-specific prefixes such as:

- `domains/example.com/`
- `domains/example.org/`

This keeps archival policy consistent while still separating objects by domain.
Teams that require stronger storage isolation can fork the module shape and move
to one bucket per domain, but the default repository path prefers simplicity.

## Trust Boundaries

Be explicit about what is public, what is private, and what has mutation
rights.

### Public By Design

- SES verification TXT values once published in DNS
- DKIM CNAME records once published in DNS
- repository source code and generic examples in the public repo

### Private Configuration

- real account IDs
- real domain list
- forwarding destinations
- hosted zone IDs
- Terraform state bucket names
- GitHub environment values
- bootstrap credentials and session tokens

### Mutation Paths

- Terraform apply can change AWS infrastructure state
- GitHub Actions can assume AWS roles through OIDC
- migration-time source DNS roles should only touch the hosted zone needed for
  verification work

## Dependency Posture

The forwarding Lambda intentionally keeps runtime dependencies very small. The
project expects operators to:

- run `npm audit --omit=dev`
- review dependency updates before merging
- prefer standard library or AWS SDK capabilities over adding new packages

## When Not To Use This Repo

Choose a different pattern if you need:

- per-user mailboxes
- end-user inbox access
- outbound campaign tooling
- heavy content inspection pipelines
- domain-level infrastructure isolation as the default architecture
