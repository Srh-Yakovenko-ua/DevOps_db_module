# Resources and logic shared by both modes (plain RDS and Aurora):
# the network placement (subnet group + security group) and the parameter group.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

locals {
  # Map the friendly engine (postgres/mysql) to the matching Aurora engine.
  aurora_engine = var.engine == "postgres" ? "aurora-postgresql" : "aurora-mysql"
  actual_engine = var.use_aurora ? local.aurora_engine : var.engine

  # Parameter-group family. When the caller does not pin one, derive it from the
  # engine and version: postgres -> "postgres<major>", mysql -> "mysql<version>".
  computed_family = var.engine == "postgres" ? "postgres${element(split(".", var.engine_version), 0)}" : "mysql${var.engine_version}"
  db_family       = coalesce(var.parameter_group_family, local.computed_family)

  # The Aurora cluster family is the same family with the aurora- prefix, so
  # switching to Aurora needs no extra variable (postgres16 -> aurora-postgresql16).
  aurora_family = var.engine == "postgres" ? replace(local.db_family, "postgres", "aurora-postgresql") : replace(local.db_family, "mysql", "aurora-mysql")

  # Aurora has no db.t3.micro, so pick a safe per-mode default when the caller
  # does not set instance_class.
  instance_class = coalesce(var.instance_class, var.use_aurora ? "db.t3.medium" : "db.t3.micro")

  # Engine default port.
  port = var.port != null ? var.port : (var.engine == "postgres" ? 5432 : 3306)

  # Use the supplied password, or the generated one.
  master_password = var.master_password != null ? var.master_password : try(random_password.master[0].result, null)

  # Writer endpoint, whichever mode is active. one([]) is null, so the inactive
  # branch never errors on a count = 0 resource.
  endpoint = var.use_aurora ? one(aws_rds_cluster.this[*].endpoint) : one(aws_db_instance.this[*].address)

  tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Module    = "rds"
  })
}

# Strong random master password when the caller does not supply one.
# override_special drops the characters RDS forbids in a password (/ @ " space).
resource "random_password" "master" {
  count            = var.master_password == null ? 1 : 0
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}

# DB subnet group: tells RDS/Aurora which subnets (AZs) it may place nodes in.
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, { Name = "${var.identifier}-subnet-group" })
}

# Security group for the database. Rules are attached separately below so the
# group itself never churns when the allow-lists change.
resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Access to the ${var.identifier} database"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.identifier}-sg" })
}

# Ingress on the DB port from each allowed CIDR block.
resource "aws_vpc_security_group_ingress_rule" "cidr" {
  count = length(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_cidr_blocks[count.index]
  from_port         = local.port
  to_port           = local.port
  ip_protocol       = "tcp"
  description       = "DB access from ${var.allowed_cidr_blocks[count.index]}"
}

# Ingress on the DB port from each allowed security group.
resource "aws_vpc_security_group_ingress_rule" "sg" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  description                  = "DB access from security group ${var.allowed_security_group_ids[count.index]}"
}

# Allow all outbound (needed for maintenance, monitoring, etc.).
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

# Parameter group for a plain RDS instance (created only when use_aurora = false).
resource "aws_db_parameter_group" "this" {
  count = var.use_aurora ? 0 : 1

  name        = "${var.identifier}-pg"
  family      = local.db_family
  description = "Parameters for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(local.tags, { Name = "${var.identifier}-pg" })
}

# Cluster parameter group for Aurora (created only when use_aurora = true).
resource "aws_rds_cluster_parameter_group" "this" {
  count = var.use_aurora ? 1 : 0

  name        = "${var.identifier}-cluster-pg"
  family      = local.aurora_family
  description = "Cluster parameters for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(local.tags, { Name = "${var.identifier}-cluster-pg" })
}
