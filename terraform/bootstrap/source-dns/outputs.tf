output "source_dns_role_arn" {
  description = "Source DNS role ARN."
  value       = aws_iam_role.source_dns.arn
}
