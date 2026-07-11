# =====================================================================
# Toggle: Aurora cluster vs a plain RDS instance
# =====================================================================
variable "use_aurora" {
  description = "true creates an Aurora cluster (writer + optional readers). false creates a single RDS instance."
  type        = bool
  default     = false
}

# =====================================================================
# Identity
# =====================================================================
variable "identifier" {
  description = "Base name for the database and all of its resources (subnet group, security group, parameter group)."
  type        = string
  default     = "app-db"
}

# =====================================================================
# Engine
# =====================================================================
variable "engine" {
  description = "Database engine. Use \"postgres\" or \"mysql\". When use_aurora is true the module maps it to aurora-postgresql / aurora-mysql automatically."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "engine must be either \"postgres\" or \"mysql\"."
  }
}

variable "engine_version" {
  description = "Engine version. A major-only value like \"16\" (postgres) or \"8.0\" (mysql) tracks the latest matching minor. Must line up with parameter_group_family."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Instance class for the DB instance / Aurora members. Null picks a sensible default: db.t3.micro for RDS, db.t3.medium for Aurora (Aurora has no micro)."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "For a plain RDS instance: run a standby in a second AZ. Ignored by Aurora (spread AZs with aurora_instance_count instead)."
  type        = bool
  default     = false
}

# =====================================================================
# Storage (plain RDS only; Aurora manages storage itself)
# =====================================================================
variable "allocated_storage" {
  description = "Initial storage in GiB for a plain RDS instance."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit in GiB for RDS storage autoscaling. Set equal to allocated_storage to disable autoscaling."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type for a plain RDS instance (gp3, gp2, io1, ...)."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Encrypt storage at rest."
  type        = bool
  default     = true
}

# =====================================================================
# Credentials
# =====================================================================
variable "database_name" {
  description = "Name of the initial database created inside the engine."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master user name."
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password. Leave null and the module generates a strong random one (exposed via the master_password output)."
  type        = string
  default     = null
  sensitive   = true
}

variable "port" {
  description = "Port the engine listens on. Null uses the engine default (5432 for postgres, 3306 for mysql)."
  type        = number
  default     = null
}

# =====================================================================
# Networking (passed in so the module stays reusable in any VPC)
# =====================================================================
variable "vpc_id" {
  description = "VPC the database and its security group live in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Give at least two, in different AZs (private subnets recommended)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "A DB subnet group needs at least two subnets in different availability zones."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the database port (for example the VPC CIDR so in-cluster apps can connect)."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to reach the database port (for example an app/node security group)."
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Give the database a public endpoint. Keep false for anything real."
  type        = bool
  default     = false
}

# =====================================================================
# Parameter group
# =====================================================================
variable "parameter_group_family" {
  description = "Parameter group family (for example postgres16, mysql8.0). Null derives it from engine + engine_version. Aurora gets the matching aurora-* family automatically."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Parameters written into the parameter group. Defaults are the PostgreSQL basics from the task. Static parameters (like max_connections) must use apply_method = \"pending-reboot\"."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = [
    { name = "max_connections", value = "200", apply_method = "pending-reboot" },
    { name = "log_statement", value = "all" },
    { name = "work_mem", value = "8192" }, # kB, i.e. 8 MB
  ]
}

# =====================================================================
# Aurora sizing
# =====================================================================
variable "aurora_instance_count" {
  description = "Number of Aurora instances. 1 is a single writer; 2+ adds read replicas across AZs for high availability."
  type        = number
  default     = 1

  validation {
    condition     = var.aurora_instance_count >= 1
    error_message = "aurora_instance_count must be at least 1 (the writer)."
  }
}

# =====================================================================
# Lifecycle / operations
# =====================================================================
variable "backup_retention_period" {
  description = "Number of days to keep automated backups."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Block deletion of the database. Keep false in a lab so terraform destroy works."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on delete. true is convenient in a lab; false is safer in production."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes at once instead of during the next maintenance window."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
