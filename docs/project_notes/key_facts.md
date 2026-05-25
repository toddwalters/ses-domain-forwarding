# Key Facts

Public-safe project facts for the reusable SES domain forwarding platform.

## Core Architecture

- one shared inbound S3 bucket
- one shared SES forwarding Lambda
- one shared SES receipt rule set
- one or more per-domain hosted zones, SES identities, DKIM records, and
  receipt rules

## Forwarding Behavior

- explicit mailbox forwarding is supported
- catch-all forwarding is supported
- per-domain sender rewrite follows `<from_local_part>@<domain>`
- forwarding configuration is stored in SSM and consumed by the shared Lambda

## Operational Controls

- GitHub Actions deploy through AWS OIDC
- Terraform manages the shared stack and per-domain resources
- readiness and smoke-test workflows provide AWS-backed operational checks
- CloudWatch alarms cover Lambda errors and throttles by default
- structured Lambda logs capture SES message IDs, routing matches, and outcomes

## Security Notes

- do not commit AWS credentials, tokens, SMTP credentials, or private keys
- keep real domain names, account IDs, and forwarding destinations in ignored
  `*.tfvars` files or GitHub environment values
- prefer zero third-party Lambda runtime dependencies
