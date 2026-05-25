output "tf_state_bucket_name" {
  description = "Terraform state bucket name."
  value       = aws_s3_bucket.tf_state.bucket
}

output "target_role_arn" {
  description = "Target account role for GitHub Actions."
  value       = aws_iam_role.github_provisioner.arn
}

output "source_dns_role_arn" {
  description = "Expected source account DNS role ARN."
  value       = local.source_dns_role_arn
}
