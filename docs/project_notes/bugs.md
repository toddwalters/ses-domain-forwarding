# Bug Log

Track bugs, operational mistakes, and fixes discovered during the email domain
consolidation work.

## Entries

### 2026-05-24 - SES Account Readiness Permission Gap

- **Issue**: The manual `15-cutover-readiness` workflow failed while checking
  whether SES production access was enabled in the target account.
- **Root Cause**: The target GitHub provisioner role could read SES identities
  and receipt rules, but it was missing `ses:GetAccount`, which backs
  `aws sesv2 get-account`.
- **Solution**: Added `ses:GetAccount` to the bootstrap-managed target
  provisioner role policy.
- **Prevention**: Include SES account-level read permissions in provisioner
  roles used by operational readiness workflows, not just identity and receipt
  rule permissions.

### 2026-05-24 - Lambda Package Hash Drift

- **Issue**: A clean post-apply Terraform plan wanted to update the Lambda
  function even though the source files had not changed.
- **Root Cause**: The Lambda build used `zip` with default file metadata, so
  GitHub checkout file mtimes changed the zip bytes and Terraform
  `source_code_hash` on every run.
- **Solution**: Make the Lambda build remove the previous artifact, normalize
  packaged file mtimes, and use `zip -X` to omit extra metadata.
- **Prevention**: Lambda packages used by Terraform `source_code_hash` should be
  deterministic across clean checkouts when source content is unchanged.

### 2026-05-24 - Lambda Code Signing Refresh Permission Gap

- **Issue**: After adding Lambda version-list read access, the next
  non-cutover `20-terraform-apply` failed during Lambda refresh before planning
  changes.
- **Root Cause**: The AWS provider also reads Lambda code signing configuration
  for managed functions, requiring `lambda:GetFunctionCodeSigningConfig`.
- **Solution**: Added `lambda:GetFunctionCodeSigningConfig` to the target
  provisioner role policy managed by the bootstrap stack.
- **Prevention**: Include Lambda code-signing read access in Terraform
  provisioner roles for Lambda functions, even when no code signing config is
  attached.

### 2026-05-24 - Lambda Version Refresh Permission Gap

- **Issue**: A resumed non-cutover `20-terraform-apply` got through the
  previous permission failures and created additional resources, then failed
  while refreshing the Lambda function.
- **Root Cause**: The target GitHub provisioner role had Lambda create, update,
  get, policy, and tag permissions, but was missing
  `lambda:ListVersionsByFunction`, which the AWS provider calls while reading
  the created function state.
- **Solution**: Added `lambda:ListVersionsByFunction` to the target provisioner
  role policy managed by the bootstrap stack.
- **Prevention**: Include Lambda version-list read permissions in Terraform
  provisioner roles for managed Lambda functions, even when version publishing
  is not explicitly configured.

### 2026-05-24 - Apply Provisioner Permission Gaps

- **Issue**: `20-terraform-apply` created some non-cutover resources, then
  failed while Terraform refreshed created resources after apply operations.
- **Root Cause**: The target GitHub provisioner role was missing provider
  management permissions for Route53 hosted zone tagging, S3 bucket CORS and
  related bucket read APIs, and SSM parameter metadata reads.
- **Solution**: Added `route53:ChangeTagsForResource`, `ssm:DescribeParameters`,
  and additional S3 bucket read permissions required by Terraform's S3 bucket
  resource refresh behavior.
- **Prevention**: When using least-privilege Terraform roles, include provider
  refresh/read permissions as well as create/update/delete permissions, because
  Terraform often reads adjacent resource subsettings immediately after create.

### 2026-05-24 - GitHub Actions Terraform Profile Null String Failure

- **Issue**: `10-terraform-plan` validated successfully and assumed the target
  provisioner role, then failed during planning with "failed to get shared
  config profile, null".
- **Root Cause**: The workflow passed `-var "target_profile=null"` and
  `-var "source_profile=null"`, which Terraform coerced into the literal string
  `null` for the AWS provider profile setting.
- **Solution**: Removed the profile variable overrides from GitHub Actions and
  changed the profile variable defaults to real Terraform `null` values. Local
  profile usage remains available by passing explicit profile variables.
- **Prevention**: For nullable string provider settings, prefer a Terraform
  `null` default for automation and explicit local overrides, rather than
  trying to pass `null` through workflow shell arguments.

### 2026-05-24 - Bootstrap Target Partial State Migration Failure

- **Issue**: `00-bootstrap-github-aws` created the target account bootstrap
  resources, then failed while moving local Terraform state into S3.
- **Root Cause**: The workflow used `terraform init` with both
  `-migrate-state` and `-reconfigure`, which Terraform rejects as mutually
  exclusive options.
- **Solution**: Removed `-reconfigure` from the first state migration path and
  added recovery logic for the case where the state bucket exists but the
  remote bootstrap state key is missing. The recovery path imports the
  previously-created S3, GitHub OIDC, IAM role, and IAM policy resources into
  local state before applying and migrating state to S3.
- **Prevention**: Keep backend reconfiguration and local-to-remote state
  migration as separate paths, and make bootstrap workflows explicitly
  recoverable after a failed post-apply state migration.

### 2026-05-24 - Bootstrap Target Backend Initialization Failure

- **Issue**: `00-bootstrap-github-aws` failed in `bootstrap-target` before
  applying resources with "Backend initialization required".
- **Root Cause**: `terraform/bootstrap/target-account/backend.tf` declared an
  S3 backend even on the first bootstrap path, where the state bucket does not
  exist yet and Terraform must start with local state.
- **Solution**: Removed the committed backend block from the bootstrap stack and
  updated the workflow to generate `backend_override.tf` only when remote state
  exists or when migrating local bootstrap state into the new state bucket.
- **Prevention**: Bootstrap stacks that create their own backend must begin with
  `terraform init -backend=false` and introduce backend configuration only after
  backend resources exist.

## Entry Format

### YYYY-MM-DD - Brief Bug Description

- **Issue**: What went wrong.
- **Root Cause**: Why it happened.
- **Solution**: How it was fixed.
- **Prevention**: How to avoid it in the future.
