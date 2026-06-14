# Bug Log

Public-safe bugs and fixes discovered in the reusable SES forwarding framework.

## Entries

### 2026-06-14 - Operator Workflows Missing Deployment Configuration

- **Issue**: AWS-backed workflows could not receive required private domain
  configuration, and scheduled drift runs failed before evaluating drift.
- **Root Cause**: Production tfvars were correctly excluded from Git without a
  replacement private input for GitHub Actions.
- **Solution**: Added `PRD_TFVARS` support and made scheduled drift opt-in for
  adopters after environment setup.
- **Prevention**: Keep private configuration transport explicit in deployment
  documentation and workflow validation.

### 2026-06-14 - Local and Drift Desired-State Regressions

- **Issue**: Local commands used an incorrect helper path, required
  migration-only inputs, reused stale backend initialization, and checked drift
  with receipt-rule activation disabled.
- **Root Cause**: Operator wrappers did not fully reflect the target-only
  steady-state configuration model.
- **Solution**: Restored optional profiles and migration arguments, corrected
  helper paths, isolated validation data, and aligned drift with active state.
- **Prevention**: Test target-only and migration operator paths separately.
