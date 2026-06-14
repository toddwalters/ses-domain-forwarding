# Architectural Decisions

Durable platform-level decisions for the reusable SES domain forwarding
framework live here.

## ADR-001: Shared Inbound Runtime

- Use one shared regional S3 bucket for raw inbound email.
- Use one shared Lambda function for forwarding across domains.
- Separate domain mail in S3 with per-domain prefixes.

Why:

- lowers cost and operational overhead
- keeps domain onboarding mostly data entry
- allows one consistent alarm and logging surface

Tradeoff:

- the Lambda and bucket become shared operational surfaces, so config review,
  alarms, and structured logging matter more.

## ADR-002: Prefer Minimal Lambda Dependencies

- Keep the forwarding Lambda at zero third-party runtime dependencies when
  practical.
- If a package becomes necessary, require lockfile-based installs, audit,
  dependency review, and explicit approval.

Why:

- easier public review
- smaller supply-chain surface
- simpler long-term maintenance

## ADR-003: Lifecycle Raw Email Storage

- Transition raw inbound email to Standard-IA after 30 days.
- Transition raw inbound email to Glacier Instant Retrieval after 90 days.

Why:

- preserves historical mail while reducing steady-state storage cost
- keeps lifecycle behavior explicit instead of leaving retention undefined

## ADR-004: Supply Production Terraform Configuration Through GitHub Secrets

- Keep complete production tfvars outside Git.
- Store them as the `PRD_TFVARS` secret in the protected `prd` GitHub
  environment.
- Materialize the secret only in the temporary runner directory for plan,
  apply, and drift operations.
- Keep scheduled drift opt-in for this reusable template until an adopter has
  configured and manually verified a live environment.

Why:

- GitHub workflows and local operators use the same Terraform configuration
  shape without publishing private domain or forwarding data.
- The public template does not generate recurring failed runs before it has
  been configured for a real deployment.
