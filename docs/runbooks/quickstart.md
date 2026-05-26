# Quickstart

Use this path when you are standing up a brand-new environment for the first
time.

## 1. Confirm The Repository Fits

Read [prerequisites.md](prerequisites.md) first. This repository is for inbound
SES forwarding, not mailbox hosting.

## 2. Create A Private Terraform Variables File

Copy the example file:

```bash
cd terraform/envs/prd
cp terraform.tfvars.example terraform.tfvars
```

Then replace the example values with your real:

- target AWS account ID
- source account ID only if you are migrating a domain
- primary region
- Terraform state bucket name
- forwarding destinations
- managed domain definitions

Keep `terraform.tfvars` private and untracked.

## 3. Author One Initial Domain

Start with one domain entry in `domain_definitions`.

For a brand-new domain in the target account:

- keep `source_dns.create_verification_records = false`
- keep `source_dns.existing_ses_verification_tokens = []`
- set `catch_all` based on the behavior you want
- set `explicit_recipients` only for addresses that need unique handling

Use [add-a-domain.md](add-a-domain.md) as the reference shape.

## 4. Validate The Lambda Package

```bash
cd ../../../lambda/ses-email-forwarder
npm test
npm audit --omit=dev
npm run build
```

## 5. Validate Terraform Locally

```bash
cd ../../terraform/envs/prd
terraform init -backend=false
terraform validate
terraform plan -refresh=false -input=false -var-file=terraform.tfvars
```

If you use named AWS profiles locally, pass them explicitly:

```bash
terraform plan -refresh=false -input=false \
  -var-file=terraform.tfvars \
  -var 'target_profile=<your-target-profile>' \
  -var 'source_profile=<your-source-profile>'
```

## 6. Configure GitHub Actions

Set the GitHub environment variables and bootstrap secrets described in
[github-actions-deployment.md](github-actions-deployment.md).

For brand-new domains that are not migrating from a source account, some
source-account variables may still exist in the workflow model, but the source
DNS path itself remains optional.

## 7. Bootstrap AWS Access

Run `00-bootstrap-github-aws` to create:

- the Terraform state bucket
- the GitHub OIDC provider
- the target provisioner role
- the optional source DNS role used only for migration-time verification writes

## 8. Plan And Apply

1. Run `10-terraform-plan`
2. Review the plan carefully
3. Run `20-terraform-apply`

If you are staging a cutover rather than going live immediately, keep
`activate_receipt_rule_set=false` until readiness checks and DNS work are done.

## 9. Verify The Environment

Use:

- `15-cutover-readiness` for pre-cutover inspection
- `18-post-cutover-smoke-test` after apply or after live changes
- CloudWatch alarms and Lambda logs for operational follow-up

## 10. Onboard The Next Domain

Once the first domain is healthy, use [add-a-domain.md](add-a-domain.md).
