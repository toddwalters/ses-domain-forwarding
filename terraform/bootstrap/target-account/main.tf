locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Environment = var.environment_name
    Scope       = "bootstrap"
  }

  source_dns_role_arn = "arn:aws:iam::${var.source_account_id}:role/${var.source_dns_role_name}"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints

  tags = local.common_tags
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.tf_state_bucket_name

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.repo_full_name}:environment:${var.environment_name}",
        "repo:${var.repo_full_name}:ref:refs/heads/main",
        "repo:${var.repo_full_name}:pull_request"
      ]
    }
  }
}

resource "aws_iam_role" "github_provisioner" {
  name               = var.target_role_name
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_provisioner" {
  statement {
    sid = "ManageTerraformState"

    actions = [
      "s3:CreateBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutBucketEncryption",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/${var.tf_state_prefix}/*"
    ]
  }

  statement {
    sid = "ManageEmailConsolidationResources"

    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:UntagResource",
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "lambda:AddPermission",
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetFunctionConfiguration",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:ListTags",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "route53:ChangeResourceRecordSets",
      "route53:ChangeTagsForResource",
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:TagResource",
      "route53domains:GetDomainDetail",
      "route53domains:ListDomains",
      "route53domains:UpdateDomainNameservers",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketLocation",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "ses:CreateReceiptRule",
      "ses:CreateReceiptRuleSet",
      "ses:DeleteIdentity",
      "ses:DeleteReceiptRule",
      "ses:DeleteReceiptRuleSet",
      "ses:DescribeActiveReceiptRuleSet",
      "ses:DescribeReceiptRule",
      "ses:DescribeReceiptRuleSet",
      "ses:GetAccount",
      "ses:GetIdentityDkimAttributes",
      "ses:GetIdentityVerificationAttributes",
      "ses:GetSendQuota",
      "ses:ListIdentities",
      "ses:ListReceiptRuleSets",
      "ses:SendRawEmail",
      "ses:SetActiveReceiptRuleSet",
      "ses:SetIdentityDkimEnabled",
      "ses:UpdateReceiptRule",
      "ses:VerifyDomainDkim",
      "ses:VerifyDomainIdentity",
      "ssm:AddTagsToResource",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListTagsForResource",
      "ssm:PutParameter",
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }

  statement {
    sid       = "AssumeSourceDnsRole"
    actions   = ["sts:AssumeRole"]
    resources = [local.source_dns_role_arn]
  }
}

resource "aws_iam_role_policy" "github_provisioner" {
  name   = "${var.target_role_name}-policy"
  role   = aws_iam_role.github_provisioner.id
  policy = data.aws_iam_policy_document.github_provisioner.json
}
