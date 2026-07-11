# Remote state in S3 with a DynamoDB lock table.
#
# The bucket name is account specific (derived from the AWS account id), so it
# is supplied at init time with -backend-config="bucket=..." which the Makefile
# does automatically. Any account can deploy this without editing the code.
terraform {
  backend "s3" {
    key            = "lesson-db-module/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
