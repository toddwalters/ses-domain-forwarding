# Domain Migration Checklist

Use this checklist when moving an existing email domain into the shared SES
forwarding stack managed by this repository.

## Before Cutover

1. Confirm the target SES identity exists and is verified.
2. Confirm DKIM is enabled and verified.
3. Confirm SES production access is enabled in the chosen sending region.
4. Confirm the shared inbound stack already exists:
   - S3 bucket
   - forwarding Lambda
   - receipt rule set
5. Confirm the domain has a managed hosted zone in the target account.
6. Confirm readiness and smoke-test workflows pass.

## During Cutover

1. Update registrar nameservers if hosted-zone authority is moving.
2. Update MX to the SES inbound endpoint for the chosen region.
3. Activate the target receipt rule set if it is still staged.
4. Send validation mail to:
   - an explicit mailbox such as `info@domain`
   - another explicit mailbox such as `abuse@domain`
   - an unconfigured catch-all address if catch-all forwarding is enabled
5. Confirm:
   - the raw message lands in S3
   - the Lambda runs successfully
   - the forwarded message reaches the destination mailbox

## After Cutover

1. Run `18-post-cutover-smoke-test`.
2. Review CloudWatch alarms and Lambda logs.
3. Disable or remove any source-account SES receipt rules and source Lambda
   resources once rollback confidence is no longer needed.
4. Remove temporary source verification records if the migration path created
   them.
5. Record any domain-specific follow-up actions outside the public repository if
   they include sensitive production details.
