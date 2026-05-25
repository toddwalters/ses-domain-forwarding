terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  alias   = "target"
  profile = var.target_profile
  region  = var.primary_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias   = "target_global"
  profile = var.target_profile
  region  = var.global_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias   = "source_global"
  profile = var.source_profile
  region  = var.global_region

  dynamic "assume_role" {
    for_each = var.source_dns_role_arn == null ? [] : [var.source_dns_role_arn]

    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = local.common_tags
  }
}
