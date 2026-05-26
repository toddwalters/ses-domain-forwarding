SHELL := /bin/bash

.PHONY: help check-tfvars lambda-build lambda-test validate bootstrap-target-validate bootstrap-source-dns-validate prd-validate prd-init-local prd-plan-local prd-apply-local prd-drift-local smoke-test-local

help:
	@echo "Available targets:"
	@echo "  make validate               - Run local validation steps"
	@echo "  make lambda-build           - Install, test, audit, and build the Lambda"
	@echo "  make prd-init-local         - Initialize the prd Terraform backend locally"
	@echo "  make prd-plan-local         - Run a local Terraform plan for prd"
	@echo "  make prd-apply-local        - Run a local Terraform apply for prd"
	@echo "  make prd-drift-local        - Run a local detailed-exitcode drift plan"
	@echo "  make smoke-test-local       - Run the post-cutover smoke test locally"
	@echo ""
	@echo "Environment variables used by local Terraform targets:"
	@echo "  TF_STATE_BUCKET"
	@echo "  TF_STATE_PREFIX"
	@echo "  AWS_REGION"
	@echo "  AWS_TARGET_ACCOUNT_ID"
	@echo "  AWS_SOURCE_ACCOUNT_ID"
	@echo "  SOURCE_HOSTED_ZONE_ID"
	@echo "  SOURCE_DNS_ROLE_NAME"
	@echo "Optional:"
	@echo "  ACTIVATE_RECEIPT_RULE_SET=true|false"
	@echo "  SMOKE_TEST_DOMAIN=<domain>"

check-tfvars:
	bash scripts/check-no-tracked-tfvars.sh

lambda-test:
	cd lambda/ses-email-forwarder && npm test

lambda-build:
	cd lambda/ses-email-forwarder && npm ci --ignore-scripts && npm audit --omit=dev && npm ls --all && npm test && npm run build

bootstrap-target-validate:
	cd terraform/bootstrap/target-account && terraform init -backend=false -input=false && terraform validate

bootstrap-source-dns-validate:
	cd terraform/bootstrap/source-dns && terraform init -backend=false -input=false && terraform validate

prd-validate:
	cd terraform/envs/prd && terraform init -backend=false -input=false && terraform validate

validate: check-tfvars lambda-build
	cd terraform && terraform fmt -check -recursive
	$(MAKE) bootstrap-target-validate
	$(MAKE) bootstrap-source-dns-validate
	$(MAKE) prd-validate

prd-init-local:
	@test -n "$(TF_STATE_BUCKET)" || (echo "TF_STATE_BUCKET is required" && exit 1)
	@test -n "$(TF_STATE_PREFIX)" || (echo "TF_STATE_PREFIX is required" && exit 1)
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is required" && exit 1)
	cd terraform/envs/prd && terraform init -input=false \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=$(TF_STATE_PREFIX)/envs/prd.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="use_lockfile=true" \
		-backend-config="encrypt=true"

prd-plan-local: lambda-build prd-init-local
	@test -n "$(AWS_TARGET_ACCOUNT_ID)" || (echo "AWS_TARGET_ACCOUNT_ID is required" && exit 1)
	@test -n "$(AWS_SOURCE_ACCOUNT_ID)" || (echo "AWS_SOURCE_ACCOUNT_ID is required" && exit 1)
	@test -n "$(SOURCE_HOSTED_ZONE_ID)" || (echo "SOURCE_HOSTED_ZONE_ID is required" && exit 1)
	@test -n "$(SOURCE_DNS_ROLE_NAME)" || (echo "SOURCE_DNS_ROLE_NAME is required" && exit 1)
	cd terraform/envs/prd && terraform validate && terraform plan -input=false -out prd.tfplan \
		-var-file=terraform.tfvars \
		-var "target_account_id=$(AWS_TARGET_ACCOUNT_ID)" \
		-var "source_account_id=$(AWS_SOURCE_ACCOUNT_ID)" \
		-var "primary_region=$(AWS_REGION)" \
		-var "source_authoritative_zone_id=$(SOURCE_HOSTED_ZONE_ID)" \
		-var "source_dns_role_arn=arn:aws:iam::$(AWS_SOURCE_ACCOUNT_ID):role/$(SOURCE_DNS_ROLE_NAME)" \
		-var "activate_receipt_rule_set=$${ACTIVATE_RECEIPT_RULE_SET:-true}"
	cd terraform/envs/prd && terraform show -json prd.tfplan > prd-plan.json
	cd terraform/envs/prd && python3 ../../scripts/render_domain_plan_summary.py prd-plan.json

prd-apply-local: lambda-build prd-init-local
	@test -n "$(AWS_TARGET_ACCOUNT_ID)" || (echo "AWS_TARGET_ACCOUNT_ID is required" && exit 1)
	@test -n "$(AWS_SOURCE_ACCOUNT_ID)" || (echo "AWS_SOURCE_ACCOUNT_ID is required" && exit 1)
	@test -n "$(SOURCE_HOSTED_ZONE_ID)" || (echo "SOURCE_HOSTED_ZONE_ID is required" && exit 1)
	@test -n "$(SOURCE_DNS_ROLE_NAME)" || (echo "SOURCE_DNS_ROLE_NAME is required" && exit 1)
	cd terraform/envs/prd && terraform apply -auto-approve -input=false \
		-var-file=terraform.tfvars \
		-var "target_account_id=$(AWS_TARGET_ACCOUNT_ID)" \
		-var "source_account_id=$(AWS_SOURCE_ACCOUNT_ID)" \
		-var "primary_region=$(AWS_REGION)" \
		-var "source_authoritative_zone_id=$(SOURCE_HOSTED_ZONE_ID)" \
		-var "source_dns_role_arn=arn:aws:iam::$(AWS_SOURCE_ACCOUNT_ID):role/$(SOURCE_DNS_ROLE_NAME)" \
		-var "activate_receipt_rule_set=$${ACTIVATE_RECEIPT_RULE_SET:-true}"

prd-drift-local: lambda-build prd-init-local
	@test -n "$(AWS_TARGET_ACCOUNT_ID)" || (echo "AWS_TARGET_ACCOUNT_ID is required" && exit 1)
	@test -n "$(AWS_SOURCE_ACCOUNT_ID)" || (echo "AWS_SOURCE_ACCOUNT_ID is required" && exit 1)
	@test -n "$(SOURCE_HOSTED_ZONE_ID)" || (echo "SOURCE_HOSTED_ZONE_ID is required" && exit 1)
	@test -n "$(SOURCE_DNS_ROLE_NAME)" || (echo "SOURCE_DNS_ROLE_NAME is required" && exit 1)
	cd terraform/envs/prd && terraform plan -detailed-exitcode -input=false \
		-var-file=terraform.tfvars \
		-var "target_account_id=$(AWS_TARGET_ACCOUNT_ID)" \
		-var "source_account_id=$(AWS_SOURCE_ACCOUNT_ID)" \
		-var "primary_region=$(AWS_REGION)" \
		-var "source_authoritative_zone_id=$(SOURCE_HOSTED_ZONE_ID)" \
		-var "source_dns_role_arn=arn:aws:iam::$(AWS_SOURCE_ACCOUNT_ID):role/$(SOURCE_DNS_ROLE_NAME)" \
		-var "activate_receipt_rule_set=false"

smoke-test-local: prd-init-local
	cd terraform/envs/prd && terraform output -json domain_hosted_zones > /tmp/domain-hosted-zones.json
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is required" && exit 1)
	AWS_REGION_VAR="$(AWS_REGION)" \
	DOMAIN_HOSTED_ZONES_JSON=/tmp/domain-hosted-zones.json \
	EXPECTED_RULE_SET_NAME="$$(cd terraform/envs/prd && terraform output -raw receipt_rule_set_name)" \
	SHARED_BUCKET_NAME="$$(cd terraform/envs/prd && terraform output -raw shared_bucket_name)" \
	FORWARDER_LAMBDA_ARN="$$(cd terraform/envs/prd && terraform output -raw forwarder_lambda_arn)" \
	SMOKE_TEST_DOMAIN="$${SMOKE_TEST_DOMAIN:-}" \
	python3 scripts/post_cutover_smoke_test.py
