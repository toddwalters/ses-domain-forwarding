# GitHub Actions Deployment Runbook

This repository deploys the SES domain forwarding stack through GitHub Actions
and AWS OIDC.

## Required GitHub Variables

Configure these environment variables before running the bootstrap workflow:

- `AWS_REGION`
- `AWS_TARGET_ACCOUNT_ID`
- `AWS_SOURCE_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_STATE_PREFIX`
- `TARGET_ROLE_NAME`
- `SOURCE_DNS_ROLE_NAME`
- `SOURCE_HOSTED_ZONE_ID`
- `DOMAIN_NAME`
- `TARGET_HOSTED_ZONE_ID`

Typical values vary by organization. Keep them in GitHub environment variables
rather than committing them into the repository.

## Required Bootstrap Secrets

These are temporary bootstrap credentials. Remove or rotate them after
bootstrap succeeds.

- `AWS_TARGET_BOOTSTRAP_ACCESS_KEY_ID`
- `AWS_TARGET_BOOTSTRAP_SECRET_ACCESS_KEY`
- `AWS_TARGET_BOOTSTRAP_SESSION_TOKEN`
- `AWS_SOURCE_BOOTSTRAP_ACCESS_KEY_ID`
- `AWS_SOURCE_BOOTSTRAP_SECRET_ACCESS_KEY`
- `AWS_SOURCE_BOOTSTRAP_SESSION_TOKEN`

## Workflow Order

1. Add bootstrap secrets and environment variables.
2. Run `00-bootstrap-github-aws`.
   - creates the Terraform state bucket
   - creates the GitHub OIDC provider and target provisioner role
   - creates the optional source-account DNS role for migration-time
     verification records
3. Open PRs normally.
   - `05-validation` runs Lambda and Terraform checks
   - `10-terraform-plan` is used when an AWS-backed plan is needed
4. Run `15-cutover-readiness` for a pre-cutover AWS state snapshot.
5. Run `18-post-cutover-smoke-test` after cutover or after operational changes.
6. Run `20-terraform-apply` after review.
7. Use `25-drift-detection` manually or on schedule.
8. Follow [domain-migration-checklist.md](domain-migration-checklist.md) for
   domain cutover work.

## Safety Notes

- Keep `activate_receipt_rule_set=false` until SES verification, production
  access, DNS, and cutover readiness are confirmed.
- The source-account DNS role should be scoped only to the hosted zone needed
  during migration.
- The normal apply workflow is not the same as the cutover workflow.
- Bootstrap credentials in GitHub are often short-lived session credentials.
  Expect to refresh them if the bootstrap workflow needs to be rerun later.
