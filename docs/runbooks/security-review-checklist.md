# Security Review Checklist

Use this checklist before adopting the repository for a real environment and
again when making meaningful infrastructure or workflow changes.

This is not a formal audit framework. It is a practical operator checklist for
the trust boundaries this repository actually creates.

## 1. Git And Repository Hygiene

- Confirm no real `terraform.tfvars`, `*.tfvars.json`, or bootstrap credential
  files are tracked in Git.
- Confirm GitHub Actions are pinned by SHA.
- Confirm example values in docs and examples are still generic and public-safe.
- Confirm no account IDs, hosted zone IDs, or live forwarding destinations have
  leaked into committed docs or workflows.

## 2. GitHub Actions And CI Trust

- Review which workflows can assume AWS roles.
- Confirm OIDC trust policies are scoped to the intended repository and branch
  or environment patterns.
- Confirm bootstrap credentials are temporary and rotated or removed after use.
- Confirm workflow permissions are minimal for each job.
- Confirm manual workflows that can change AWS state are clearly separated from
  validation-only workflows.

## 3. Terraform State And Secrets

- Confirm the Terraform state bucket is encrypted.
- Confirm state access is limited to the intended operators and automation.
- Confirm bootstrap secrets, GitHub environment values, and real tfvars are
  stored privately.
- Confirm no sensitive mail-routing values are written to public docs or step
  summaries.

## 4. IAM And AWS Role Scope

- Review the target provisioner role permissions and remove anything no longer
  needed.
- Confirm the migration-time source DNS role is scoped only to the hosted zone
  it must touch.
- Confirm the Lambda execution role has only the S3, SSM, SES send, and log
  permissions it needs.
- Confirm CloudWatch alarm and read permissions match the intended operator
  workflows.

## 5. SES And Mail Flow Controls

- Confirm only intended domains are enabled in `domain_definitions`.
- Confirm `migration_overrides` is empty for steady-state domains.
- Confirm catch-all routing is enabled only where intentionally desired.
- Confirm forwarding destinations are reviewed and correct.
- Confirm SES production access is enabled in the intended region before live
  sending use.
- Confirm the active receipt rule set is the expected one.

## 6. S3 And Raw Email Storage

- Confirm the inbound bucket is private.
- Confirm lifecycle rules match retention expectations.
- Confirm object prefixes are domain-scoped as expected.
- Confirm no unnecessary public access policies, ACLs, or cross-account grants
  exist on the bucket.

## 7. Lambda And Dependency Safety

- Run `npm test`.
- Run `npm audit --omit=dev`.
- Review dependency changes before merge.
- Prefer standard library or AWS SDK capabilities over new third-party
  packages.
- Confirm structured logs do not emit raw message bodies or other unnecessarily
  sensitive content.

## 8. Logging And Observability

- Confirm CloudWatch alarms exist and are reviewed.
- Confirm Logs Insights queries still match the structured log fields the Lambda
  emits.
- Confirm error logs include enough context to diagnose routing issues without
  exposing entire messages.
- Confirm operator runbooks cover both plan-time and runtime troubleshooting.

## 9. Domain Migration Safety

- Confirm nameserver and MX cutover steps are operator-reviewed rather than
  assumed.
- Confirm source verification records are temporary and removed after migration.
- Confirm source receipt rules and forwarding paths are retired after rollback
  confidence is no longer needed.

## 10. Quick Threat Model

The highest-value abuse paths to think about here are:

- accidental forwarding to the wrong destination due to config mistakes
- over-broad IAM roles or GitHub OIDC trust
- leaked private configuration through Git or CI summaries
- excessive Lambda dependencies or unsafe dependency upgrades
- unexpected catch-all routing that forwards mail you did not mean to forward
- raw inbound email retention that exceeds operator intent

When in doubt, review changes through those six lenses first.
