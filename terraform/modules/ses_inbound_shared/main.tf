locals {
  config_parameter_name = "/ses-email-forwarder/domain-config"
  receipt_rule_arn      = "arn:aws:ses:${var.region}:${var.account_id}:receipt-rule-set/${var.receipt_rule_set_name}:receipt-rule/*"
}

resource "aws_s3_bucket" "inbound" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "inbound" {
  bucket = aws_s3_bucket.inbound.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "inbound" {
  bucket = aws_s3_bucket.inbound.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inbound" {
  bucket = aws_s3_bucket.inbound.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inbound" {
  bucket = aws_s3_bucket.inbound.id

  rule {
    id     = "raw-email-storage-transitions"
    status = "Enabled"

    filter {
      prefix = "domains/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

data "aws_iam_policy_document" "ses_bucket_write" {
  statement {
    sid = "AllowSESPuts"

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.inbound.arn}/domains/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [local.receipt_rule_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "inbound" {
  bucket = aws_s3_bucket.inbound.id
  policy = data.aws_iam_policy_document.ses_bucket_write.json
}

resource "aws_cloudwatch_log_group" "forwarder" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_metric_alarm" "forwarder_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  alarm_description   = "Alert when the SES email forwarder Lambda reports errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = var.error_alarm_period_seconds
  evaluation_periods  = var.error_alarm_evaluation_periods
  threshold           = var.error_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    FunctionName = aws_lambda_function.forwarder.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "forwarder_throttles" {
  alarm_name          = "${var.lambda_function_name}-throttles"
  alarm_description   = "Alert when the SES email forwarder Lambda is throttled."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = var.throttle_alarm_period_seconds
  evaluation_periods  = var.throttle_alarm_evaluation_periods
  threshold           = var.throttle_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    FunctionName = aws_lambda_function.forwarder.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "forwarder_low_invocations" {
  count = var.enable_low_invocation_alarm ? 1 : 0

  alarm_name          = "${var.lambda_function_name}-low-invocations"
  alarm_description   = "Alert when the SES email forwarder Lambda receives fewer invocations than expected."
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  statistic           = "Sum"
  period              = var.low_invocation_alarm_period_seconds
  evaluation_periods  = var.low_invocation_alarm_evaluation_periods
  threshold           = var.low_invocation_alarm_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    FunctionName = aws_lambda_function.forwarder.function_name
  }
}

resource "aws_ssm_parameter" "domain_config" {
  name  = local.config_parameter_name
  type  = "String"
  value = jsonencode(var.domain_forwarding_config)
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "forwarder" {
  name               = var.lambda_function_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid = "WriteLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["${aws_cloudwatch_log_group.forwarder.arn}:*"]
  }

  statement {
    sid = "ReadInboundMail"

    actions = [
      "s3:GetObject"
    ]

    resources = ["${aws_s3_bucket.inbound.arn}/domains/*"]
  }

  statement {
    sid = "SendForwardedMail"

    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }

  statement {
    sid = "ReadDomainConfig"

    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.domain_config.arn]
  }
}

resource "aws_iam_role_policy" "forwarder" {
  name   = "${var.lambda_function_name}-policy"
  role   = aws_iam_role.forwarder.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_lambda_function" "forwarder" {
  function_name    = var.lambda_function_name
  description      = "Shared SES inbound email forwarder"
  role             = aws_iam_role.forwarder.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = var.lambda_package_path
  source_code_hash = filebase64sha256(var.lambda_package_path)

  environment {
    variables = {
      CONFIG_PARAMETER_NAME               = aws_ssm_parameter.domain_config.name
      INBOUND_BUCKET_NAME                 = aws_s3_bucket.inbound.bucket
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.forwarder,
    aws_iam_role_policy.forwarder
  ]
}

resource "aws_ses_receipt_rule_set" "forwarding" {
  rule_set_name = var.receipt_rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "forwarding" {
  count = var.activate_receipt_rule_set ? 1 : 0

  rule_set_name = aws_ses_receipt_rule_set.forwarding.rule_set_name
}
