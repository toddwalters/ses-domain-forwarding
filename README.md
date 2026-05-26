# SES Domain Forwarding

Terraform and Lambda scaffolding for managing one or more Amazon SES inbound
email domains and forwarding messages to one or more downstream addresses.

The repository is designed for teams that want:

- a shared SES inbound stack in one AWS account and region
- one or more managed Route53 hosted zones and SES identities
- per-domain forwarding rules, including catch-all behavior
- GitHub Actions deployment through AWS OIDC
- a small forwarding Lambda with zero third-party runtime dependencies

The public repo now treats steady-state domain behavior and migration-only
overrides as separate concerns, so onboarding a brand-new domain does not
require carrying source-DNS migration fields in the normal domain definition.

Start here:

1. Read [docs/runbooks/prerequisites.md](docs/runbooks/prerequisites.md) to
   confirm the repository fits your use case.
2. Follow [docs/runbooks/quickstart.md](docs/runbooks/quickstart.md) for the
   first working environment.
3. Use [docs/runbooks/add-a-domain.md](docs/runbooks/add-a-domain.md) when you
   are ready to onboard another domain.
4. Use [docs/runbooks/domain-migration-checklist.md](docs/runbooks/domain-migration-checklist.md)
   only when moving an existing domain from another setup.

## What This Repository Covers

- shared SES receipt rule set, inbound S3 bucket, Lambda, and SSM config
- per-domain SES identity, DKIM, hosted zone, MX, and receipt rule resources
- optional source-account Route53 support for migration-time verification
- readiness, smoke-test, apply, and drift-detection GitHub workflows
- CloudWatch alarms and structured Lambda logs for operational visibility

## What This Repository Is Not

This repository is a good fit for inbound forwarding and lightweight routing.
It is not intended to be:

- a full mailbox hosting system
- a user-facing email product with IMAP or POP access
- a bulk outbound email platform
- a general-purpose mail processing pipeline with arbitrary custom logic

If your needs look more like mailbox hosting, outbound campaigns, or complex
message workflows, this repo is probably the wrong starting point.

## Quick Start

The shortest path to a first working environment is:

1. Copy [terraform/envs/prd/terraform.tfvars.example](terraform/envs/prd/terraform.tfvars.example)
   to a private local `terraform.tfvars`.
2. Fill in your real AWS account IDs, bucket name, and one initial domain.
3. Build and validate the Lambda package:

```bash
cd lambda/ses-email-forwarder
npm test
npm audit --omit=dev
npm run build
```

4. Validate Terraform locally:

```bash
cd ../../terraform/envs/prd
terraform init -backend=false
terraform validate
terraform plan -refresh=false -input=false -var-file=terraform.tfvars
```

5. Configure the GitHub environment variables and bootstrap secrets described
   in [docs/runbooks/github-actions-deployment.md](docs/runbooks/github-actions-deployment.md).
6. Run `00-bootstrap-github-aws`.
7. Run `10-terraform-plan`, review both the Terraform plan and the domain
   summary in the GitHub step summary, then run `20-terraform-apply`.

The detailed version of this path lives in
[docs/runbooks/quickstart.md](docs/runbooks/quickstart.md).

## Public-Safe Design

This repository is structured so that environment-specific values are provided
through Terraform variables, GitHub environment variables, or ignored local
`*.tfvars` files rather than committed directly into source control.

Sensitive or organization-specific values that should stay out of Git include:

- AWS account IDs and named local AWS profiles
- real domain names and hosted zone IDs
- real forwarding destinations
- Terraform state bucket names
- bootstrap credentials and session tokens

See [terraform/envs/prd/terraform.tfvars.example](terraform/envs/prd/terraform.tfvars.example)
for a public-safe example environment authoring file. The example includes
multiple domains so the one-to-many authoring shape is visible without needing
to infer it from module internals.

Real `terraform.tfvars` and `*.tfvars.json` files should stay private and
untracked. This repository ignores them through `.gitignore`, and CI validation
fails if any non-example Terraform variable file is committed.

## Repository Layout

- `lambda/ses-email-forwarder/`: forwarding Lambda package and tests
- `terraform/modules/`: reusable SES/Lambda/domain modules
- `terraform/envs/prd/`: example live environment composition
- `terraform/bootstrap/`: GitHub OIDC and optional source-DNS bootstrap stacks
- `.github/workflows/`: validation, plan, apply, smoke-test, and drift workflows
- `docs/runbooks/`: generic deployment and migration runbooks

## Operator Paths

- New environment: [docs/runbooks/quickstart.md](docs/runbooks/quickstart.md)
- Add a domain: [docs/runbooks/add-a-domain.md](docs/runbooks/add-a-domain.md)
- Migrate an existing domain: [docs/runbooks/domain-migration-checklist.md](docs/runbooks/domain-migration-checklist.md)
- GitHub Actions deployment: [docs/runbooks/github-actions-deployment.md](docs/runbooks/github-actions-deployment.md)
- Local operator equivalents: [docs/runbooks/local-operator-workflows.md](docs/runbooks/local-operator-workflows.md)
- Architecture and security notes: [docs/runbooks/architecture-and-security.md](docs/runbooks/architecture-and-security.md)
- Security review checklist: [docs/runbooks/security-review-checklist.md](docs/runbooks/security-review-checklist.md)
- CloudWatch Logs Insights cookbook: [docs/runbooks/cloudwatch-logs-insights-cookbook.md](docs/runbooks/cloudwatch-logs-insights-cookbook.md)
- Improvement backlog: [docs/runbooks/improvement-backlog.md](docs/runbooks/improvement-backlog.md)

If some workflow or Terraform names feel more implementation-oriented than
operator-oriented, the deployment and local-operator runbooks now include a
short naming glossary.

## Local Validation

```bash
cd lambda/ses-email-forwarder
npm test
npm audit --omit=dev
npm run build

cd ../../terraform/envs/prd
terraform init -backend=false
terraform validate
terraform plan -refresh=false -input=false \
  -var-file=terraform.tfvars
```

If you prefer a lightweight task runner for common local flows, use:

```bash
make help
```

## GitHub Actions

Deployment is intended to run through GitHub Actions using AWS OIDC:

- `00-bootstrap-github-aws`
- `05-validation`
- `10-terraform-plan`
- `15-cutover-readiness`
- `18-post-cutover-smoke-test`
- `20-terraform-apply`
- `25-drift-detection`

See [docs/runbooks/github-actions-deployment.md](docs/runbooks/github-actions-deployment.md)
for the generic deployment flow and required variable categories.

## Architecture Defaults

- shared inbound S3 bucket and shared forwarding Lambda
- per-domain raw-email prefixes such as `domains/example.com/`
- sender rewrite pattern: `<from_local_part>@<domain>`
- optional catch-all forwarding per domain
- raw email lifecycle transitions:
  - Standard-IA after 30 days
  - Glacier Instant Retrieval after 90 days
