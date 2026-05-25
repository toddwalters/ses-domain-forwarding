# Architectural Decisions

This file records durable design decisions for the reusable SES domain
forwarding platform.

## Decisions

### ADR-001: Use a Shared Inbound Bucket and Shared Forwarding Lambda

**Decision:**

- Use one shared regional S3 bucket for raw inbound email.
- Use one shared Lambda function for forwarding across domains.
- Separate domain mail in S3 with per-domain prefixes.

**Consequences:**

- Domain-specific configuration must be data-driven rather than hard-coded.
- Shared operational checks should report by domain even though the runtime is
  shared.

### ADR-002: Prefer Zero Third-Party Lambda Dependencies

**Decision:**

- Implement the forwarding Lambda with zero third-party runtime dependencies if
  practical.
- If a package becomes necessary, require lockfile-based installs, audit,
  dependency review, and explicit approval.

**Consequences:**

- The runtime stays easier to inspect and safer to publish publicly.
- MIME handling and header rewriting should stay as small and testable as
  possible.

### ADR-003: Archive Raw Email to Cheaper S3 Storage

**Decision:**

- Transition raw inbound email to Standard-IA after 30 days.
- Transition raw inbound email to Glacier Instant Retrieval after 90 days.

**Consequences:**

- The shared inbound bucket always needs lifecycle rules.
- Historical mail handling should be explicitly decided during migrations rather
  than assumed.
