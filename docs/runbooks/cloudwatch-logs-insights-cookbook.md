# CloudWatch Logs Insights Cookbook

Use these queries when troubleshooting the shared SES forwarding Lambda.

The Lambda emits structured JSON logs, so the goal here is fast operational
answers rather than ad hoc text searching.

## Before You Start

Open CloudWatch Logs Insights and select the log group for the forwarding
Lambda, typically:

- `/aws/lambda/ses-email-forwarder`

Pick a time range that covers the event you care about before running the
queries.

## 1. Latest Events

Use this to get a quick feel for what the Lambda has been doing recently.

```sql
fields @timestamp, level, message, domain, sesMessageId, awsRequestId
| sort @timestamp desc
| limit 50
```

## 2. Failures Only

Use this when the alarm fired or mail appears to be missing.

```sql
fields @timestamp, level, message, domain, sesMessageId, awsRequestId, errorMessage
| filter level = "error"
| sort @timestamp desc
| limit 50
```

## 3. One SES Message End To End

Use this when you know the SES message ID and want the full request trail.

Replace `SES_MESSAGE_ID_HERE` with the actual value.

```sql
fields @timestamp, level, message, domain, sesMessageId, awsRequestId, recipientMatches, transformedRecipients, errorMessage
| filter sesMessageId = "SES_MESSAGE_ID_HERE"
| sort @timestamp asc
```

## 4. One Lambda Invocation End To End

Use this when you have the Lambda request ID from an error or a prior query.

Replace `AWS_REQUEST_ID_HERE` with the actual value.

```sql
fields @timestamp, level, message, domain, sesMessageId, awsRequestId, recipientMatches, transformedRecipients, errorMessage
| filter awsRequestId = "AWS_REQUEST_ID_HERE"
| sort @timestamp asc
```

## 5. Routing Decisions

Use this to see how recipient matching resolved, including exact, catch-all,
or local-part matches.

```sql
fields @timestamp, domain, originalRecipient, recipientMatches, transformedRecipients
| filter message = "Resolved forwarding recipients."
| sort @timestamp desc
| limit 50
```

## 6. Catch-All Traffic

Use this to understand how often catch-all routing is being used.

```sql
fields @timestamp, domain, recipientMatches, transformedRecipients
| filter message = "Resolved forwarding recipients."
| filter recipientMatches like /catch_all/
| sort @timestamp desc
| limit 50
```

## 7. Domains With The Most Recent Activity

Use this to see which domains are active and roughly how much they are using
the shared Lambda.

```sql
fields domain
| filter ispresent(domain)
| stats count(*) as events by domain
| sort events desc
```

## 8. Most Common Error Messages

Use this to spot repeated operational issues quickly.

```sql
fields errorMessage
| filter level = "error"
| stats count(*) as occurrences by errorMessage
| sort occurrences desc
```

## 9. S3 Fetch Problems

Use this when you suspect mail landed in SES but could not be pulled from S3.

```sql
fields @timestamp, domain, sesMessageId, bucket, key, errorMessage
| filter message = "Fetching raw email from S3." or level = "error"
| sort @timestamp desc
| limit 50
```

## 10. Delivery Outcomes

Use this to separate mail that was sent onward from mail that was skipped or
failed.

```sql
fields @timestamp, level, message, domain, sesMessageId, transformedRecipients, errorMessage
| filter message in ["Forwarding finished successfully.", "Forwarding stopped.", "Forwarding failed."]
| sort @timestamp desc
| limit 50
```

## Suggested Troubleshooting Order

When forwarding appears broken:

1. Check CloudWatch alarms.
2. Run the **Failures Only** query.
3. If you have a specific SES message ID, run **One SES Message End To End**.
4. If routing looks wrong, run **Routing Decisions** and **Catch-All Traffic**.
5. If the message was fetched but never forwarded, compare the log trail with
   the domain config and Terraform plan summary.

## Notes

- `recipientMatches` is the best field for understanding why a recipient was
  routed the way it was.
- `sesMessageId` is the best cross-log identifier for one inbound message.
- `awsRequestId` is the best identifier for one Lambda invocation.
