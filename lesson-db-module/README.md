# Flexible Terraform database module (RDS / Aurora)

This theme's deliverable is a single, reusable Terraform module,
**`modules/rds`**, that builds either a plain **RDS instance** or an **Aurora
cluster**, decided by one flag: `use_aurora`. In both modes it also creates the
database's subnet group, security group and parameter group, so one `module`
block gives you a complete, ready to connect database.

The module does not live on its own. This course builds one project across
themes 5-7-8-9-10, so the repo carries the **whole accumulated stack** (remote
state backend, VPC, ECR, EKS, the Jenkins + Argo CD CI/CD loop and the Dealsbe
Helm chart) and the new `rds` module is wired into it. The database sits in the
private subnets of the same VPC the EKS cluster uses, so the application pods can
reach it with no public endpoint.

If you only want to see the module work, `make db-only` brings up just the VPC
and the database (no cluster, no CI/CD), which is quick and cheap.

```hcl
module "rds" {
  source     = "./modules/rds"
  identifier = "app-db"
  use_aurora = false          # flip to true for an Aurora cluster

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

## Table of contents

1. [The rds module (the deliverable)](#the-rds-module-the-deliverable)
2. [Using the module](#using-the-module)
3. [Inputs](#inputs)
4. [Outputs](#outputs)
5. [How to change things](#how-to-change-things)
6. [Project structure (the accumulated stack)](#project-structure-the-accumulated-stack)
7. [How grading maps to this repo](#how-grading-maps-to-this-repo)
8. [Quick start](#quick-start)
9. [The rest of the project (CI/CD)](#the-rest-of-the-project-cicd)
10. [Local validation](#local-validation)
11. [Teardown](#teardown)

## The rds module (the deliverable)

One flag, `use_aurora`, switches the whole shape of the database. Everything
around it (networking, parameters, credentials) is the same either way.

| Resource | `use_aurora = false` | `use_aurora = true` |
|----------|----------------------|---------------------|
| Compute  | `aws_db_instance` | `aws_rds_cluster` + `aws_rds_cluster_instance` (writer, plus readers if you ask) |
| Parameter group | `aws_db_parameter_group` | `aws_rds_cluster_parameter_group` |
| Subnet group | `aws_db_subnet_group` (always) | same |
| Security group | `aws_security_group` + ingress/egress rules (always) | same |

The two compute shapes are toggled with `count` on each resource
(`rds.tf` uses `count = var.use_aurora ? 0 : 1`, `aurora.tf` the reverse), so
exactly one is ever created. Outputs read the created one safely with
`one(resource[*]...)`, so the unused branch never errors.

The security group opens only the engine port (5432 for postgres, 3306 for
mysql) to whatever you list in `allowed_cidr_blocks` and
`allowed_security_group_ids`, and nothing else.

Handy conveniences built in:

* **`engine` is `postgres` or `mysql`.** When `use_aurora = true` the module maps
  it to `aurora-postgresql` / `aurora-mysql` for you.
* **`parameter_group_family` is derived** from `engine` + `engine_version`
  (`postgres16`, `mysql8.0`, ...), with the matching `aurora-*` family for Aurora.
  You can still override it.
* **`instance_class` null picks a default:** `db.t3.micro` for RDS,
  `db.t3.medium` for Aurora (Aurora has no micro class).
* **`master_password` null generates a strong random one** (via the `random`
  provider), exposed on the `master_password` output.

## Using the module

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
terraform output -raw db_password
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

At the root, these are re-exposed as `db_endpoint`, `db_reader_endpoint`,
`db_port`, `db_name`, `db_username`, `db_password`, `db_is_aurora` and
`db_connection_command`.

## How to change things

Everything is a variable, so common changes are one line:

* **Switch to Aurora:** set `use_aurora = true`. If you keep the default
  `db.t3.micro` the module bumps it to `db.t3.medium` for you, since Aurora has
  no micro class.
* **Change the engine version:** set `engine_version` (the family is derived to
  match), for example `engine_version = "15"` gives family `postgres15`.
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

At the root, the same knobs are exposed as `db_*` variables (see
`terraform.tfvars.example`), for example `db_use_aurora`, `db_engine`,
`db_instance_class`.

## Project structure (the accumulated stack)

The project grows theme by theme (5-7-8-9-10). Every module from the earlier
themes is here; this theme adds `modules/rds` and wires it into the root.

```
lesson-db-module/
├── main.tf                 # Wires all modules: s3-backend, vpc, ecr, eks, rds, jenkins, argo_cd
├── platform.tf             # gp3 default StorageClass + metrics-server
├── provider.tf             # aws + kubernetes + helm (exec auth to EKS)
├── backend.tf              # S3 + DynamoDB remote state
├── versions.tf             # Terraform + provider pins (aws, random, kubernetes, helm, tls)
├── variables.tf            # All inputs, including the db_* passthroughs to modules/rds
├── locals.tf               # Tags, AZs, account-derived names, in-repo paths
├── outputs.tf              # ECR/EKS/Jenkins/Argo outputs + the db_* outputs
├── Makefile                # db-only, phased bootstrap, access helpers, safe destroy
├── Jenkinsfile             # The CI/CD pipeline (generic; values come from JCasC)
├── terraform.tfvars.example
│
├── modules/
│   ├── s3-backend/         # S3 bucket + DynamoDB table for state          (theme 5)
│   ├── vpc/                # VPC, public/private subnets, IGW, NAT          (theme 5-7)
│   ├── ecr/                # ECR repository + policy + lifecycle            (theme 7)
│   ├── eks/                # EKS cluster, IAM, OIDC/IRSA, EBS CSI driver    (theme 7)
│   │   └── aws_ebs_csi_driver.tf
│   ├── rds/                # >>> THIS THEME: the RDS / Aurora module <<<    (theme 10)
│   │   ├── rds.tf          #   aws_db_instance          (use_aurora = false)
│   │   ├── aurora.tf       #   aws_rds_cluster + members (use_aurora = true)
│   │   ├── shared.tf       #   subnet group, security group, parameter groups, locals
│   │   ├── variables.tf    #   every input, typed and documented
│   │   └── outputs.tf      #   endpoint, port, password, ...
│   ├── jenkins/            # Helm Jenkins configured as code (JCasC)        (theme 8-9)
│   └── argo_cd/            # Helm Argo CD + the Dealsbe Application          (theme 8-9)
│       └── charts/         #   app-of-apps chart
│
├── charts/
│   └── django-app/         # The Dealsbe Helm chart (Deployment, Service, ConfigMap, HPA)
│
├── app/                    # Dealsbe application (Django), the Docker build context
└── scripts/
    └── push-to-ecr.sh      # Manual/first image push (seed :latest)
```

## How grading maps to this repo

| Criterion (points) | Where |
|--------------------|-------|
| Universal rds module (30) | `modules/rds/` |
| Aurora + RDS via `use_aurora` (25) | `rds.tf`, `aurora.tf`, the `count` on each resource |
| Subnet group + Security group + Parameter group (20) | `modules/rds/shared.tf` |
| Variables with types, descriptions, defaults (15) | `modules/rds/variables.tf` |
| README with usage and examples (10) | this file |

The module is wired into the accumulated project's `main.tf` (`module "rds"`),
so it is not an isolated folder: it takes the VPC's private subnets and the VPC
CIDR as its allowed range, exactly as the final project would use it.

## Quick start

Prerequisites: Terraform >= 1.5, AWS CLI configured (`aws configure`).

**Just the database module (fast, cheap, no cluster):**

```bash
cd lesson-db-module
make db-only          # local state, brings up only the VPC + a Postgres RDS
make db-endpoint      # host:port
make db-password      # the generated master password
make db-info          # a ready to run psql/mysql command

make db-only DB_AURORA=true   # build an Aurora cluster instead
make db-only-destroy          # tear the db-only stack down
```

**The full accumulated stack (VPC + ECR + EKS + RDS + Jenkins + Argo CD):**

```bash
make bootstrap
# = make backend   (phase 1: S3+DynamoDB state backend, then migrate state)
#   make infra     (phase 2: VPC + ECR + EKS + RDS       ~15 min)
#   make platform  (phase 3: StorageClass, metrics-server, Jenkins, Argo CD)
```

The full stack needs `git_repo_url` (and a GitHub token for the CI/CD loop), the
same as themes 8-9. Copy `terraform.tfvars.example` to `terraform.tfvars` and
export `TF_VAR_github_token`. The `db-only` path needs none of that.

## The rest of the project (CI/CD)

The Jenkins + Argo CD GitOps loop carried over from themes 8-9 still works:
Jenkins builds the Dealsbe image with Kaniko, pushes it to ECR, bumps
`charts/django-app/values.yaml` and pushes to Git; Argo CD then auto-syncs the
cluster. The application, once deployed, connects to the `rds` database over the
VPC (the security group allows the VPC CIDR). Access helpers:

```bash
make kubeconfig
make jenkins-url   make jenkins-password
make argocd-url    make argocd-password
make app-url       make status
```

## Local validation

No AWS account needed for these:

```bash
make fmt            # terraform fmt -recursive
make validate       # terraform init -backend=false && terraform validate
helm lint charts/django-app
helm lint modules/argo_cd/charts
```

## Teardown

Always destroy after you are done. Cloud databases and clusters are not free.

```bash
make destroy          # full stack: app LB -> jenkins/argo/eks/rds/vpc/ecr -> backend
# or, if you used the quick path:
make db-only-destroy  # just the VPC + database (local state)
```

`make destroy` removes the LoadBalancers and cluster first, then the database and
VPC, then the S3 bucket and DynamoDB table that hold the state (it copies the
state local before deleting the backend so the last step can run). Because that
also deletes the backend, the next full deploy starts from `make bootstrap`
again, which recreates it.
