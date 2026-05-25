locals {
  safe_domain_name                = replace(var.domain, ".", "-")
  receipt_rule_arn                = "arn:aws:ses:${var.region}:${var.account_id}:receipt-rule-set/${var.receipt_rule_set_name}:receipt-rule/${local.safe_domain_name}-forwarding"
  source_ses_verification_records = distinct(concat(var.source_existing_ses_verification_tokens, [aws_ses_domain_identity.this.verification_token]))
  dkim_record_indexes             = toset(["0", "1", "2"])
}

resource "aws_route53_zone" "this" {
  name    = var.domain
  comment = var.hosted_zone_comment
}

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.${var.region}.amazonaws.com"]
}

resource "aws_route53_record" "extra" {
  for_each = var.extra_records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

resource "aws_ses_domain_identity" "this" {
  domain = var.domain
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

resource "aws_route53_record" "ses_verification_target" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = 1800
  records = [aws_ses_domain_identity.this.verification_token]
}

resource "aws_route53_record" "dkim_target" {
  for_each = local.dkim_record_indexes

  zone_id = aws_route53_zone.this.zone_id
  name    = "${aws_ses_domain_dkim.this.dkim_tokens[tonumber(each.key)]}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_ses_domain_dkim.this.dkim_tokens[tonumber(each.key)]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_verification_source" {
  count = var.create_source_verification_records ? 1 : 0

  provider = aws.source_dns

  allow_overwrite = true
  zone_id         = var.source_authoritative_zone_id
  name            = "_amazonses.${var.domain}"
  type            = "TXT"
  ttl             = 1800
  records         = local.source_ses_verification_records
}

resource "aws_route53_record" "dkim_source" {
  for_each = var.create_source_verification_records ? local.dkim_record_indexes : toset([])

  provider = aws.source_dns

  zone_id = var.source_authoritative_zone_id
  name    = "${aws_ses_domain_dkim.this.dkim_tokens[tonumber(each.key)]}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_ses_domain_dkim.this.dkim_tokens[tonumber(each.key)]}.dkim.amazonses.com"]
}

resource "aws_lambda_permission" "allow_ses_invoke" {
  statement_id   = "AllowSESToInvoke${replace(title(local.safe_domain_name), "-", "")}"
  action         = "lambda:InvokeFunction"
  function_name  = var.forwarder_lambda_arn
  principal      = "ses.amazonaws.com"
  source_account = var.account_id
  source_arn     = local.receipt_rule_arn
}

resource "aws_ses_receipt_rule" "forwarding" {
  name          = "${local.safe_domain_name}-forwarding"
  rule_set_name = var.receipt_rule_set_name
  recipients    = [var.domain]
  enabled       = var.receipt_rule_enabled
  scan_enabled  = true
  tls_policy    = "Optional"

  s3_action {
    bucket_name       = var.inbound_bucket_name
    object_key_prefix = var.s3_object_key_prefix
    position          = 1
  }

  lambda_action {
    function_arn    = var.forwarder_lambda_arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_lambda_permission.allow_ses_invoke
  ]
}
