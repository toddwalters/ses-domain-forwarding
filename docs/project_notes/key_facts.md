# Key Facts

Public-safe facts that help operators understand the reusable SES domain
forwarding framework quickly.

## Architecture

- one shared inbound S3 bucket
- one shared SES forwarding Lambda
- one shared SES receipt rule set
- one or more per-domain hosted zones, SES identities, DKIM records, and
  receipt rules

## Forwarding Model

- explicit mailbox forwarding is supported
- catch-all forwarding is supported
- per-domain sender rewrite follows `<from_local_part>@<domain>`
- forwarding configuration is stored in SSM and consumed by the shared Lambda
- raw email is stored under per-domain S3 prefixes such as `domains/example.com/`

## Operator Surface

- GitHub Actions deploy through AWS OIDC by default
- equivalent local operator commands are documented
- readiness and smoke-test workflows provide AWS-backed operational checks
- CloudWatch alarms cover Lambda errors and throttles by default
- structured Lambda logs capture SES message IDs, routing matches, and outcomes

## Security Posture

- do not commit AWS credentials, tokens, SMTP credentials, or private keys
- keep real domain names, account IDs, and forwarding destinations in ignored
  `*.tfvars` files or GitHub environment values
- prefer minimal Lambda runtime dependencies
- keep migration-only overrides separate from steady-state domain definitions
