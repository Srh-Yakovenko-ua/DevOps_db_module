# AWS provider. Tags below are applied to every taggable resource.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
