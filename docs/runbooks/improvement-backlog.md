# Improvement Backlog

This backlog keeps the public repository focused on becoming a dependable,
reusable SES forwarding framework rather than only a sanitized migration artifact.

## Current Priorities

### 1. First-Run Clarity

Status: in progress

- strengthen the README quickstart
- add a dedicated quickstart runbook
- add a concrete add-a-domain runbook
- make the intended operator paths obvious from the README

### 2. Architecture Clarity

Status: in progress

- document the shared-stack design and tradeoffs
- document what the repo is not intended to do
- explain the trust boundaries around public DNS data, private config, and AWS
  mutation paths

### 3. Multi-Domain Operator Experience

Status: in progress

- add a dry-run report that summarizes which domains, receipt rules, and
  forwarding routes will be created
- split steady-state domain config from migration-only overrides
- add another realistic multi-domain example beyond the basic sample

### 4. Observability

Status: in progress

- add a CloudWatch Logs Insights query cookbook
- consider a small dashboard for Lambda invocations, errors, throttles, and
  alarm state
- explore per-domain metrics if troubleshooting needs become more granular

### 5. Security And Release Hygiene

Status: in progress

- pin GitHub Actions by SHA
- add a short threat model or security review checklist
- document how operators should review Lambda dependency updates

Current progress:

- GitHub Actions are pinned by SHA.
- A repository-grounded security review checklist is now included.

### 6. CI Portability

Status: in progress

- ensure each GitHub workflow has an obvious local equivalent
- document which workflows are convenience layers versus required deployment
  mechanics

### 7. Public Repo Cleanup

Status: planned

- trim down project-memory residue that is more private-history than public
  framework value
- review workflow names and variable names for maximum generic clarity

## Near-Term Implementation Order

1. First-run clarity
2. Architecture clarity
3. Multi-domain operator experience
4. Observability
5. Security and release hygiene
