# Reusable RDS / Aurora Terraform module

A single, production ready Terraform module that builds either a plain **RDS
instance** or an **Aurora cluster**, decided by one flag: `use_aurora`. In both
modes it also creates the database's subnet group, security group and parameter
group, so you get a complete, ready to connect database from one `module` block.

```hcl
module "rds" {
  source     = "./modules/rds"
  identifier = "app-db"
  use_aurora = false          # flip to true for an Aurora cluster

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

## What it creates

| Resource | use_aurora = false | use_aurora = true |
|----------|--------------------|-------------------|
| Compute  | `aws_db_instance` | `aws_rds_cluster` + `aws_rds_cluster_instance` (writer, and readers if you ask for them) |
| Parameter group | `aws_db_parameter_group` | `aws_rds_cluster_parameter_group` |
| Subnet group | `aws_db_subnet_group` (always) | same |
| Security group | `aws_security_group` + ingress/egress rules (always) | same |

The security group opens the engine port (5432 for postgres, 3306 for mysql) to
whatever you list in `allowed_cidr_blocks` and `allowed_security_group_ids`, and
nothing else.

## Project layout

```
lesson-db-module/
├── main.tf              # Wires s3-backend + vpc + rds
├── backend.tf           # S3 + DynamoDB remote state
├── provider.tf          # AWS provider
├── versions.tf          # Terraform + provider versions (aws, random)
├── variables.tf         # Root inputs (region, network, db_* toggles)
├── locals.tf            # Tags, AZs, account-derived bucket name
├── outputs.tf           # Endpoint, port, generated password, ...
├── Makefile             # bootstrap / apply / apply-aurora / destroy / helpers
│
└── modules/
    ├── rds/             # THE module this homework is about
    │   ├── rds.tf       #   aws_db_instance          (use_aurora = false)
    │   ├── aurora.tf    #   aws_rds_cluster + members (use_aurora = true)
    │   ├── shared.tf    #   subnet group, security group, parameter groups, locals
    │   ├── variables.tf #   every input, typed and documented
    │   └── outputs.tf   #   endpoint, port, password, ...
    ├── vpc/             # Small VPC so the demo runs end to end (NAT is optional)
    └── s3-backend/      # S3 bucket + DynamoDB table for the state
```

The `vpc` and `s3-backend` modules are here only so the root is runnable out of
the box. The graded work is `modules/rds`.

## Quick start (the runnable demo)

Prerequisites: Terraform >= 1.5, AWS CLI configured (`aws configure`).

```bash
cd lesson-db-module
make bootstrap        # creates the S3/DynamoDB backend, then VPC + a Postgres RDS
make db-info          # endpoint, port, user, database name
make db-password      # the generated master password
```

Build an Aurora cluster instead:

```bash
make apply-aurora     # same as: terraform apply -var="use_aurora=true"
```

Tear everything down when you are done (see the note about order at the bottom):

```bash
make destroy
```

## Using the module on its own

Minimal PostgreSQL instance:

```hcl
module "rds" {
  source = "./modules/rds"

  identifier = "app-db"
  use_aurora = false

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"
  # parameter_group_family is derived as postgres16 automatically

  database_name   = "appdb"
  master_username = "dbadmin"
  # master_password omitted -> a strong random one is generated

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = ["10.0.0.0/16"]
}
```

Aurora PostgreSQL with a writer and one reader:

```hcl
module "rds" {
  source = "./modules/rds"

  identifier            = "app-db"
  use_aurora            = true
  engine                = "postgres"       # module maps it to aurora-postgresql
  instance_class        = "db.t3.medium"   # Aurora has no micro class
  aurora_instance_count = 2                # 1 writer + 1 reader

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

Connect with the outputs:

```bash
terraform output -raw db_endpoint
terraform output -raw db_master_password
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `use_aurora` | bool | `false` | `true` builds an Aurora cluster, `false` a single RDS instance. |
| `identifier` | string | `"app-db"` | Base name for the database and every resource around it. |
| `engine` | string | `"postgres"` | `postgres` or `mysql`. Mapped to `aurora-postgresql` / `aurora-mysql` when `use_aurora` is true. |
| `engine_version` | string | `"16"` | Engine version. A major-only value (like `16`) tracks the latest minor. |
| `instance_class` | string | `null` | Instance size. Null uses `db.t3.micro` for RDS and `db.t3.medium` for Aurora. |
| `multi_az` | bool | `false` | Plain RDS: run a standby in a second AZ. Ignored by Aurora. |
| `allocated_storage` | number | `20` | Initial storage (GiB) for a plain RDS instance. |
| `max_allocated_storage` | number | `100` | Storage autoscaling ceiling (GiB). Equal to `allocated_storage` disables it. |
| `storage_type` | string | `"gp3"` | Storage type for a plain RDS instance. |
| `storage_encrypted` | bool | `true` | Encrypt storage at rest. |
| `database_name` | string | `"appdb"` | Name of the initial database. |
| `master_username` | string | `"dbadmin"` | Master user name. |
| `master_password` | string | `null` | Master password. Null generates a strong random one. |
| `port` | number | `null` | Listener port. Null uses the engine default (5432 / 3306). |
| `vpc_id` | string | (required) | VPC for the database and its security group. |
| `subnet_ids` | list(string) | (required) | Subnets for the DB subnet group (two or more AZs). |
| `allowed_cidr_blocks` | list(string) | `[]` | CIDRs allowed to reach the DB port. |
| `allowed_security_group_ids` | list(string) | `[]` | Security groups allowed to reach the DB port. |
| `publicly_accessible` | bool | `false` | Give the database a public endpoint. |
| `parameter_group_family` | string | `null` | Parameter group family. Null derives it from engine + version. Aurora derives its own. |
| `parameters` | list(object) | max_connections, log_statement, work_mem | Parameters written into the parameter group. |
| `aurora_instance_count` | number | `1` | Aurora members. 1 is a lone writer; 2+ adds readers. |
| `backup_retention_period` | number | `7` | Days of automated backups. |
| `deletion_protection` | bool | `false` | Block deletion. Keep off in a lab. |
| `skip_final_snapshot` | bool | `true` | Skip the final snapshot on delete. |
| `apply_immediately` | bool | `true` | Apply changes now instead of during maintenance. |
| `tags` | map(string) | `{}` | Extra tags on every resource. |

## Outputs

| Name | Description |
|------|-------------|
| `endpoint` | Writer endpoint (cluster endpoint for Aurora, instance address for RDS). |
| `reader_endpoint` | Aurora reader endpoint (null for plain RDS). |
| `port` | Port the database listens on. |
| `database_name`, `master_username` | Connection details. |
| `master_password` | The password (generated when you did not set one). Sensitive. |
| `security_group_id`, `db_subnet_group_name`, `parameter_group_name` | The supporting resources. |
| `is_aurora`, `engine` | What was actually built. |
| `connection_command` | A ready to run `psql` / `mysql` command. |

## How to change things

Everything is a variable, so common changes are one line:

* **Switch to Aurora:** set `use_aurora = true`. If you keep the default
  `db.t3.micro` the module bumps it to `db.t3.medium` for you, since Aurora has
  no micro class.
* **Change the engine version:** set `engine_version` and a matching
  `parameter_group_family`, for example `engine_version = "15"` with
  `parameter_group_family = "postgres15"`.
* **Change the instance class:** set `instance_class = "db.t3.small"` (or any
  class valid for the engine).
* **Use MySQL:** set `engine = "mysql"` and `engine_version = "8.0"` (the family
  is derived as `mysql8.0` automatically), and override `parameters`, since the
  defaults are PostgreSQL specific:

  ```hcl
  parameters = [
    { name = "max_connections", value = "200", apply_method = "pending-reboot" },
    { name = "slow_query_log",  value = "1" },
  ]
  ```
* **Add read replicas (Aurora):** set `aurora_instance_count = 3`.
* **High availability (plain RDS):** set `multi_az = true`.
* **Tune parameters:** edit the `parameters` list. Static parameters such as
  `max_connections` must use `apply_method = "pending-reboot"`.

## How grading maps to this repo

| Criterion (points) | Where |
|--------------------|-------|
| Universal rds module (30) | `modules/rds/` |
| Aurora + RDS via `use_aurora` (25) | `rds.tf`, `aurora.tf`, the `count` on each resource |
| Subnet group + Security group + Parameter group (20) | `modules/rds/shared.tf` |
| Variables with types, descriptions, defaults (15) | `modules/rds/variables.tf` |
| README with usage and examples (10) | this file |

## Teardown, and the order that matters

Always destroy after you are done. Cloud databases are not free.

```bash
make destroy
```

`make destroy` removes the database and VPC first, then the S3 bucket and
DynamoDB table that hold the state (it copies the state to a local file before
deleting the backend so the last step can run). Because that also deletes the
backend, the next deploy has to start from `make bootstrap` again, which
recreates it.
