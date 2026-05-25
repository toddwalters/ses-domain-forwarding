output "hosted_zone_id" {
  description = "Target hosted zone ID."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Target hosted zone nameservers."
  value       = aws_route53_zone.this.name_servers
}

output "ses_identity_arn" {
  description = "SES domain identity ARN."
  value       = aws_ses_domain_identity.this.arn
}

output "receipt_rule_name" {
  description = "SES receipt rule name."
  value       = aws_ses_receipt_rule.forwarding.name
}

output "ses_verification_record" {
  description = "SES domain verification TXT record."
  value = {
    name  = aws_route53_record.ses_verification_target.name
    type  = aws_route53_record.ses_verification_target.type
    value = aws_ses_domain_identity.this.verification_token
  }
}

output "dkim_records" {
  description = "SES DKIM CNAME records."
  value = [
    for token in aws_ses_domain_dkim.this.dkim_tokens : {
      name  = "${token}._domainkey.${var.domain}"
      type  = "CNAME"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}
