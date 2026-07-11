# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project name, used as a resource name prefix and in tags"
  type        = string
  default     = "lesson-db-module"
}

# ---------------------------------------------------------------------------
# Remote state backend
# ---------------------------------------------------------------------------
variable "state_bucket_name" {
  description = "S3 bucket for the Terraform state. Empty derives a unique name from the account id."
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-locks"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (the database lives here), one per AZ"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# ---------------------------------------------------------------------------
# Database (passed through to the rds module)
# ---------------------------------------------------------------------------
variable "use_aurora" {
  description = "true builds an Aurora cluster; false builds a single RDS instance"
  type        = bool
  default     = false
}

variable "db_identifier" {
  description = "Base name for the database and its resources"
  type        = string
  default     = "app-db"
}

variable "db_engine" {
  description = "Database engine: postgres or mysql"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Engine version (must line up with db_parameter_group_family)"
  type        = string
  default     = "16"
}

variable "db_parameter_group_family" {
  description = "Parameter group family (for example postgres16, mysql8.0). Null derives it from db_engine + db_engine_version."
  type        = string
  default     = null
}

variable "db_instance_class" {
  description = "Instance class. Null uses db.t3.micro for RDS, db.t3.medium for Aurora."
  type        = string
  default     = null
}

variable "db_multi_az" {
  description = "Run a standby in a second AZ (plain RDS only)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master user name"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password. Null generates a strong random one (see the db_master_password output)."
  type        = string
  default     = null
  sensitive   = true
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances (1 = writer only; 2+ adds read replicas)"
  type        = number
  default     = 1
}
