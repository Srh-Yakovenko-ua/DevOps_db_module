# Current region availability zones and the caller AWS account.
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  # Global tags applied to every resource through the provider default_tags.
  common_tags = {
    Project   = var.project
    ManagedBy = "Terraform"
  }

  # Pick as many AZs as the longest subnet list needs, straight from the region.
  azs = slice(data.aws_availability_zones.available.names, 0, max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs)))

  # When state_bucket_name is empty, build a unique name from the project and
  # the AWS account id, so any account can deploy without editing the code.
  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}
