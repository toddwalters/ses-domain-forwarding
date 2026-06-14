# GitHub Actions Deployment Runbook

This repository deploys the SES domain forwarding stack through GitHub Actions
and AWS OIDC.

If you need local equivalents for these workflows, use
[local-operator-workflows.md](local-operator-workflows.md).

## Required GitHub Variables

Configure these environment variables before running the bootstrap workflow:

- `AWS_REGION`
  - the primary AWS region for SES receiving and deployment
- `AWS_TARGET_ACCOUNT_ID`
  - the AWS account that will host the shared forwarding stack
- `TF_STATE_BUCKET`
  - the S3 bucket that stores Terraform state
- `TF_STATE_PREFIX`
  - the state-key prefix used within the Terraform state bucket
- `TARGET_ROLE_NAME`
  - the GitHub-assumable provisioner role in the target account

Configure these additional environment variables only when migrating a domain
from a source account or hosted zone:

- `AWS_SOURCE_ACCOUNT_ID`
  - the source AWS account used only for migration-time DNS support
- `SOURCE_DNS_ROLE_NAME`
  - the migration-time DNS role in the source account
- `SOURCE_HOSTED_ZONE_ID`
  - the source hosted zone ID used only for migration-time verification writes
- `DOMAIN_NAME`
  - the operator-selected domain used by the cutover-readiness workflow
- `TARGET_HOSTED_ZONE_ID`
  - the hosted zone ID for the target domain used by cutover readiness

Typical values vary by organization. Keep them in GitHub environment variables
rather than committing them into the repository.

## Required Production Configuration Secret

Create a `PRD_TFVARS` secret in the `prd` GitHub environment. Its value should
be the complete contents of the private
`terraform/envs/prd/terraform.tfvars` file.

The plan, apply, and drift workflows materialize this secret into a temporary
runner file and pass it to Terraform with `-var-file`. This keeps domain names,
forwarding destinations, bucket names, and other environment-specific values
out of the repository.

From an authenticated local checkout, configure or refresh the secret with:

```bash
gh secret set PRD_TFVARS \
  --repo <github-owner>/<github-repo> \
  --env prd \
  < terraform/envs/prd/terraform.tfvars
```

Refresh this secret whenever the private production tfvars change.

## Naming Notes

Some workflow variable names are intentionally implementation-specific because
they match Terraform inputs, AWS resources, or existing workflow behavior.

Operator translations:

- "target" means the account that will own the shared SES forwarding stack
- "source" means the account or zone a domain is being migrated from
- "DNS role" means a migration-only role for temporary verification-record work
- "receipt rule set activation" means making the shared SES rule set live for
  inbound processing

If you are onboarding a brand-new domain rather than migrating one, the
`AWS_SOURCE_ACCOUNT_ID`, `SOURCE_DNS_ROLE_NAME`, and `SOURCE_HOSTED_ZONE_ID`
concepts may exist in the workflow model without being active parts of the
steady-state operator path.

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

1. Add bootstrap secrets, environment variables, and `PRD_TFVARS`.
2. Run `00-bootstrap-github-aws`.
   - creates the Terraform state bucket
   - creates the GitHub OIDC provider and target provisioner role
   - creates the optional source-account DNS role for migration-time
     verification records
3. Open PRs normally.
   - `05-validation` runs Lambda and Terraform checks
   - `10-terraform-plan` is used when an AWS-backed plan is needed and now
     includes a domain-level summary in the GitHub step summary
4. Run `15-cutover-readiness` for a pre-cutover AWS state snapshot.
5. Run `18-post-cutover-smoke-test` after cutover or after operational changes.
6. Run `20-terraform-apply` after review.
7. Use `25-drift-detection` manually after the environment is configured.
   Add a schedule to that workflow only after a successful manual drift run.
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
