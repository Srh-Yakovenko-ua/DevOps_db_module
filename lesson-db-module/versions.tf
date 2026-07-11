# Terraform and provider version constraints.
#   * aws    - VPC, RDS/Aurora, S3/DynamoDB state backend
#   * random - generates the DB master password when one is not supplied
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}
