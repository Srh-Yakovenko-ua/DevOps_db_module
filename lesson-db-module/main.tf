# Root module: wires the S3 state backend, a VPC and the reusable rds module.
# Every value has a sensible default, so `terraform apply` builds a plain
# PostgreSQL RDS instance out of the box. Flip use_aurora=true for Aurora.

# Remote state storage: S3 bucket plus a DynamoDB lock table.
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = local.state_bucket_name
  table_name  = var.lock_table_name
}

# Network: a VPC with public and private subnets across the region AZs. The
# database sits in the private subnets. NAT is off because a database has no
# need to reach the internet, which keeps the lab cheap.
module "vpc" {
  source             = "./modules/vpc"
  vpc_name           = "${var.project}-vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnet_cidrs
  private_subnets    = var.private_subnet_cidrs
  availability_zones = local.azs
  enable_nat_gateway = false
}

# The star of the show: a single reusable module that builds either a plain
# RDS instance or an Aurora cluster, plus its subnet group, security group and
# parameter group.
module "rds" {
  source = "./modules/rds"

  identifier             = var.db_identifier
  use_aurora             = var.use_aurora
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  parameter_group_family = var.db_parameter_group_family
  instance_class         = var.db_instance_class
  multi_az               = var.db_multi_az
  aurora_instance_count  = var.aurora_instance_count

  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password

  # Place the database in the private subnets and let anything inside the VPC
  # reach it. Narrow allowed_cidr_blocks / allowed_security_group_ids for prod.
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [var.vpc_cidr_block]

  tags = local.common_tags
}
