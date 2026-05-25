locals {
  target_role_arn = "arn:aws:iam::${var.target_account_id}:role/${var.target_role_name}"
  hosted_zone_arn = "arn:aws:route53:::hostedzone/${var.source_authoritative_zone_id}"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Scope     = "bootstrap-source-dns"
  }
}

data "aws_iam_policy_document" "assume_from_target" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.target_role_arn]
    }
  }
}

resource "aws_iam_role" "source_dns" {
  name               = var.source_dns_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_from_target.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "source_dns" {
  statement {
    sid = "ManageTemporaryVerificationRecords"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets"
    ]

    resources = [local.hosted_zone_arn]
  }

  statement {
    sid = "ObserveRoute53Changes"

    actions = [
      "route53:GetChange",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "source_dns" {
  name   = "${var.source_dns_role_name}-policy"
  role   = aws_iam_role.source_dns.id
  policy = data.aws_iam_policy_document.source_dns.json
}
