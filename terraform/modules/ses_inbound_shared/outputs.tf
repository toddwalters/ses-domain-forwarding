output "alarm_names" {
  description = "CloudWatch alarm names for the shared forwarder Lambda."
  value = compact([
    aws_cloudwatch_metric_alarm.forwarder_errors.alarm_name,
    aws_cloudwatch_metric_alarm.forwarder_throttles.alarm_name,
    try(aws_cloudwatch_metric_alarm.forwarder_low_invocations[0].alarm_name, null),
  ])
}

output "bucket_name" {
  description = "Shared inbound S3 bucket name."
  value       = aws_s3_bucket.inbound.bucket
}

output "bucket_arn" {
  description = "Shared inbound S3 bucket ARN."
  value       = aws_s3_bucket.inbound.arn
}

output "lambda_function_arn" {
  description = "Shared forwarder Lambda ARN."
  value       = aws_lambda_function.forwarder.arn
}

output "lambda_function_name" {
  description = "Shared forwarder Lambda name."
  value       = aws_lambda_function.forwarder.function_name
}

output "receipt_rule_set_name" {
  description = "SES receipt rule set name."
  value       = aws_ses_receipt_rule_set.forwarding.rule_set_name
}

output "config_parameter_name" {
  description = "SSM parameter containing domain forwarding configuration."
  value       = aws_ssm_parameter.domain_config.name
}
