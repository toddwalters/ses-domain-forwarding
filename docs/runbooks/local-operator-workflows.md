# Local Operator Workflows

Use this runbook when you want to perform the same kinds of checks or deploy
steps as the GitHub workflows, but from a local machine.

This does not replace the GitHub Actions path as the default. It gives you a
clear local equivalent when CI is unavailable, when you want to troubleshoot a
workflow step, or when you want to validate changes before pushing.

If you want a lightweight wrapper around the most common local commands, use
the repository `Makefile` and start with:

```bash
make help
```

## Assumptions

- you have a private `terraform.tfvars`
- your AWS credentials or named profiles can reach the target account
- you have Terraform, Node.js, npm, and the AWS CLI installed
- you are running commands from the repository root unless otherwise noted

## Naming Cheatsheet

- target account: the AWS account that will own the shared forwarding stack
- source account: the AWS account a migrating domain is moving from
- source hosted zone: the DNS zone used only for migration-time SES
  verification support
- receipt rule set activation: whether the shared SES inbound rule set is live
- steady-state domain config: `domain_definitions`
- migration-only domain config: `migration_overrides`

## `05-validation`

GitHub workflow purpose:

- verify Lambda package health
- verify Terraform formatting
- verify Terraform module/env validity

Local equivalent:

```bash
bash scripts/check-no-tracked-tfvars.sh

cd lambda/ses-email-forwarder
npm ci --ignore-scripts
npm audit --omit=dev
npm ls --all
npm test
npm run build

cd ../../terraform
terraform fmt -check -recursive

cd bootstrap/target-account
terraform init -backend=false -input=false
terraform validate

cd ../source-dns
terraform init -backend=false -input=false
terraform validate

cd ../../envs/prd
terraform init -backend=false -input=false
terraform validate
```

## `10-terraform-plan`

GitHub workflow purpose:

- produce an AWS-backed Terraform plan
- emit a domain summary alongside the raw plan output

Local equivalent:

```bash
cd lambda/ses-email-forwarder
npm ci --ignore-scripts
npm test
npm run build

cd ../../terraform/envs/prd
terraform init -input=false \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-prefix>/envs/prd.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform validate

terraform plan -input=false -out prd.tfplan \
  -var-file=terraform.tfvars \
  -var "target_account_id=<target-account-id>" \
  -var "source_account_id=<source-account-id>" \
  -var "primary_region=<aws-region>" \
  -var "source_authoritative_zone_id=<source-hosted-zone-id>" \
  -var "source_dns_role_arn=arn:aws:iam::<source-account-id>:role/<source-dns-role-name>" \
  -var "activate_receipt_rule_set=true"

terraform show -json prd.tfplan > prd-plan.json
python3 ../../scripts/render_domain_plan_summary.py prd-plan.json
```

## `15-cutover-readiness`

GitHub workflow purpose:

- inspect SES verification, DKIM, production access, active receipt rule set,
  and nameserver alignment before cutover

Local equivalent:

Run the same AWS CLI queries directly:

```bash
AWS_REGION=<aws-region>
DOMAIN_NAME=<domain>
TARGET_HOSTED_ZONE_ID=<target-hosted-zone-id>

aws ses get-identity-verification-attributes \
  --region "$AWS_REGION" \
  --identities "$DOMAIN_NAME"

aws ses get-identity-dkim-attributes \
  --region "$AWS_REGION" \
  --identities "$DOMAIN_NAME"

aws sesv2 get-account --region "$AWS_REGION"

aws ses describe-active-receipt-rule-set \
  --region "$AWS_REGION"

aws route53 get-hosted-zone --id "$TARGET_HOSTED_ZONE_ID"

aws route53domains get-domain-detail \
  --region us-east-1 \
  --domain-name "$DOMAIN_NAME"
```

## `18-post-cutover-smoke-test`

GitHub workflow purpose:

- verify live readiness after cutover or meaningful operational changes

Local equivalent:

```bash
cd terraform/envs/prd
terraform init -input=false \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-prefix>/envs/prd.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform output -json domain_hosted_zones > /tmp/domain-hosted-zones.json

AWS_REGION_VAR=<aws-region> \
DOMAIN_HOSTED_ZONES_JSON=/tmp/domain-hosted-zones.json \
EXPECTED_RULE_SET_NAME="$(terraform output -raw receipt_rule_set_name)" \
SHARED_BUCKET_NAME="$(terraform output -raw shared_bucket_name)" \
FORWARDER_LAMBDA_ARN="$(terraform output -raw forwarder_lambda_arn)" \
python3 ../../scripts/post_cutover_smoke_test.py
```

To test only one domain:

```bash
SMOKE_TEST_DOMAIN=<domain> \
AWS_REGION_VAR=<aws-region> \
DOMAIN_HOSTED_ZONES_JSON=/tmp/domain-hosted-zones.json \
EXPECTED_RULE_SET_NAME="$(terraform output -raw receipt_rule_set_name)" \
SHARED_BUCKET_NAME="$(terraform output -raw shared_bucket_name)" \
FORWARDER_LAMBDA_ARN="$(terraform output -raw forwarder_lambda_arn)" \
python3 ../../scripts/post_cutover_smoke_test.py
```

## `20-terraform-apply`

GitHub workflow purpose:

- apply the `prd` environment using the target provisioner role

Local equivalent:

```bash
cd lambda/ses-email-forwarder
npm ci --ignore-scripts
npm audit --omit=dev
npm ls --all
npm test
npm run build

cd ../../terraform/envs/prd
terraform init -input=false \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-prefix>/envs/prd.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform apply -auto-approve -input=false \
  -var-file=terraform.tfvars \
  -var "target_account_id=<target-account-id>" \
  -var "source_account_id=<source-account-id>" \
  -var "primary_region=<aws-region>" \
  -var "source_authoritative_zone_id=<source-hosted-zone-id>" \
  -var "source_dns_role_arn=arn:aws:iam::<source-account-id>:role/<source-dns-role-name>" \
  -var "activate_receipt_rule_set=<true-or-false>"
```

## `25-drift-detection`

GitHub workflow purpose:

- run a detailed-exitcode plan to detect configuration drift

Local equivalent:

```bash
cd lambda/ses-email-forwarder
npm ci --ignore-scripts
npm run build

cd ../../terraform/envs/prd
terraform init -input=false \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-prefix>/envs/prd.tfstate" \
  -backend-config="region=<aws-region>" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform plan -detailed-exitcode -input=false \
  -var-file=terraform.tfvars \
  -var "target_account_id=<target-account-id>" \
  -var "source_account_id=<source-account-id>" \
  -var "primary_region=<aws-region>" \
  -var "source_authoritative_zone_id=<source-hosted-zone-id>" \
  -var "source_dns_role_arn=arn:aws:iam::<source-account-id>:role/<source-dns-role-name>" \
  -var "activate_receipt_rule_set=false"
```

Interpretation:

- exit code `0`: no drift
- exit code `2`: drift detected
- any other nonzero exit code: command failure

## `00-bootstrap-github-aws`

GitHub workflow purpose:

- create the target bootstrap resources and optional source DNS role

Local equivalent:

This workflow is more stateful and environment-specific than the others. The
same Terraform stacks can be run locally, but only with the same caution you
would apply to a privileged bootstrap action.

Target account bootstrap:

```bash
cd terraform/bootstrap/target-account
terraform init -backend=false -input=false
terraform apply -auto-approve -input=false \
  -var "region=<aws-region>" \
  -var "target_account_id=<target-account-id>" \
  -var "source_account_id=<source-account-id>" \
  -var "repo_full_name=<github-owner>/<github-repo>" \
  -var "environment_name=prd" \
  -var "tf_state_bucket_name=<tf-state-bucket>" \
  -var "tf_state_prefix=<tf-state-prefix>" \
  -var "target_role_name=<target-role-name>" \
  -var "source_dns_role_name=<source-dns-role-name>"
```

Source DNS role bootstrap:

```bash
cd ../source-dns
terraform init -backend=false -input=false
terraform apply -auto-approve -input=false \
  -var "target_account_id=<target-account-id>" \
  -var "source_account_id=<source-account-id>" \
  -var "target_role_name=<target-role-name>" \
  -var "source_dns_role_name=<source-dns-role-name>" \
  -var "source_authoritative_zone_id=<source-hosted-zone-id>"
```

## Notes

- GitHub Actions remains the default operating path for this repository.
- These local equivalents are mainly for debugging, recovery, and pre-push
  confidence.
- Keep local credentials, private tfvars, and state configuration out of Git.
