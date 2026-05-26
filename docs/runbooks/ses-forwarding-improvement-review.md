# SES Forwarding Improvement Review

This review captures the highest-value candidate improvements that emerged from
looking at the current repository design alongside current Amazon SES and AWS
Lambda guidance.

The goal is not to say the repository is incomplete or unsafe today. It is to
identify the next set of features that could make the platform more resilient,
observable, and deliverability-friendly as more domains come onboard.

## Current Baseline

Today the repository already does a lot well:

- manages SES identities and DKIM records per domain
- creates a shared inbound receipt rule set
- stores raw inbound mail in S3
- scans inbound mail for spam and viruses
- forwards via a shared Lambda
- emits structured logs
- creates Lambda alarms for errors and throttles

Key current implementation points:

- receipt rules enable scanning, but use `tls_policy = "Optional"` and async
  Lambda invocation in
  [terraform/modules/ses_forwarded_domain/main.tf](../../terraform/modules/ses_forwarded_domain/main.tf)
- the shared inbound bucket uses S3-managed encryption (`AES256`) and the
  Lambda reads config from SSM in
  [terraform/modules/ses_inbound_shared/main.tf](../../terraform/modules/ses_inbound_shared/main.tf)
- the forwarder rewrites and re-sends with `SendRawEmail`, but does not persist
  idempotency state or configure async failure capture in
  [lambda/ses-email-forwarder/index.js](../../lambda/ses-email-forwarder/index.js)

## Recommendation Summary

Suggested order:

1. Lambda async failure capture
2. Duplicate suppression by SES message ID
3. Outbound bounce and complaint notifications
4. Custom `MAIL FROM` support
5. SES receipt-rule metrics alarms
6. Optional verdict-based quarantine or rejection
7. Optional KMS encryption for raw-email storage

The first five are the strongest candidates for near-term work. The last two
are still good ideas, but they introduce more policy or operator complexity and
do not feel as urgent.

## 1. Lambda Async Failure Capture

- Recommendation:
  Add optional Lambda asynchronous failure capture using an on-failure
  destination or dead-letter queue.
- Why it matters:
  SES invokes the forwarder Lambda asynchronously. If forwarding fails badly
  enough, the event can be retried and eventually discarded. Right now the repo
  logs failures, but it does not preserve failed events in a separate system
  for follow-up.
- Likely implementation:
  Add optional SQS or SNS resources plus `aws_lambda_function_event_invoke_config`
  for the shared forwarder Lambda.
- Suggested default:
  Optional, but strongly recommended in production.
- Tradeoff:
  Adds a new queue/topic to manage and document.

## 2. Duplicate Suppression By SES Message ID

- Recommendation:
  Add optional idempotency tracking keyed by SES message ID.
- Why it matters:
  AWS Lambda asynchronous processing can result in retries or duplicate
  deliveries. The current forwarder does not persist a dedupe marker, so the
  same message could be forwarded twice.
- Likely implementation:
  Add an optional DynamoDB table with TTL and check/write by SES message ID
  before the send step.
- Suggested default:
  Optional in the module, recommended for production domains.
- Tradeoff:
  Adds statefulness and a small per-message read/write cost.

## 3. Outbound Bounce And Complaint Notifications

- Recommendation:
  Add optional SES feedback notification support for forwarded outbound mail.
- Why it matters:
  The platform sends forwarded mail through SES, but it does not currently
  expose bounce, complaint, or delivery signals as first-class infrastructure.
  That makes downstream deliverability issues harder to observe.
- Likely implementation:
  Add optional SNS topics or configuration-set event publishing for bounce,
  complaint, and delivery notifications.
- Suggested default:
  Optional in the module, recommended once the repo manages real production
  domains.
- Tradeoff:
  Adds event plumbing and another operator surface to document.

## 4. Custom `MAIL FROM` Support

- Recommendation:
  Add optional custom `MAIL FROM` support per domain.
- Why it matters:
  The repository manages DKIM, but not custom `MAIL FROM`. Custom `MAIL FROM`
  improves SPF alignment and usually gives a cleaner DMARC story for forwarded
  outbound mail.
- Likely implementation:
  Add optional `mail_from_subdomain` input, the matching SES identity config,
  and required MX/TXT records in Route53.
- Suggested default:
  Optional, but a strong candidate for production-facing domains.
- Tradeoff:
  Adds more DNS surface area and a few more domain-specific inputs.

## 5. SES Receipt-Rule Metrics Alarms

- Recommendation:
  Add optional SES receiving alarms in addition to the existing Lambda alarms.
- Why it matters:
  Today the repository alarms on Lambda behavior, but not on SES receiving
  pipeline metrics such as publish failures or expired publishes. That means
  some receipt-rule problems could be missed until mail stops arriving.
- Likely implementation:
  Add CloudWatch alarms for receipt-rule or receipt-rule-set metrics like
  `PublishFailure`, `PublishExpired`, and optionally low `Received` volume.
- Suggested default:
  Optional, but a strong observability improvement.
- Tradeoff:
  These alarms need careful thresholds to avoid noisy false positives.

## 6. Optional Verdict-Based Quarantine Or Rejection

- Recommendation:
  Consider an optional policy layer for spam, virus, SPF, DKIM, or DMARC
  verdicts instead of always forwarding every matched inbound message.
- Why it matters:
  The receipt rule already enables SES scanning, but the current Lambda does
  not act on receipt verdicts. That means suspicious messages can still be
  forwarded if they match routing rules.
- Likely implementation:
  Extend the domain config schema with a simple policy mode such as:
  `forward_all`, `quarantine_suspicious`, or `drop_failed_auth`.
  The Lambda could inspect `record.ses.receipt` verdicts and either forward,
  skip, or redirect to a quarantine prefix.
- Suggested default:
  Keep current behavior as default; make stricter handling opt-in.
- Tradeoff:
  This changes message-handling behavior and needs careful operator education.

## 7. Optional KMS Encryption For Raw Email Storage

- Recommendation:
  Add optional SSE-KMS support for the inbound raw-email bucket.
- Why it matters:
  The bucket currently uses S3-managed encryption (`AES256`). That is already a
  reasonable default, but some teams will want customer-managed KMS keys for
  tighter key control, key rotation visibility, or compliance reasons.
- Likely implementation:
  Add optional KMS key inputs and wire them into the bucket encryption config,
  SES write permissions, and Lambda read permissions.
- Suggested default:
  Keep `AES256` as the simple default, offer KMS as an opt-in mode.
- Tradeoff:
  KMS increases policy complexity and can complicate cross-service permissions.

## Proposed Next Step

If we continue this work incrementally, the strongest next slice is:

1. implement Lambda async failure capture
2. implement duplicate suppression
3. add outbound feedback notifications

That sequence improves failure handling first, then correctness, then
deliverability visibility, without immediately forcing behavior changes on
message acceptance or DNS policy.
