# --- State backend ---------------------------------------------------------
output "state_bucket_name" {
  description = "S3 bucket that stores the Terraform state"
  value       = module.s3_backend.bucket_name
}

# --- Network ---------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets the database runs in"
  value       = module.vpc.private_subnet_ids
}

# --- Database --------------------------------------------------------------
output "db_is_aurora" {
  description = "Whether an Aurora cluster (true) or a plain RDS instance (false) was created"
  value       = module.rds.is_aurora
}

output "db_engine" {
  description = "Effective database engine"
  value       = module.rds.engine
}

output "db_endpoint" {
  description = "Writer endpoint to connect to"
  value       = module.rds.endpoint
}

output "db_reader_endpoint" {
  description = "Aurora reader endpoint (null for a plain RDS instance)"
  value       = module.rds.reader_endpoint
}

output "db_port" {
  description = "Port the database listens on"
  value       = module.rds.port
}

output "db_name" {
  description = "Initial database name"
  value       = module.rds.database_name
}

output "db_username" {
  description = "Master user name"
  value       = module.rds.master_username
}

output "db_master_password" {
  description = "Master password (the generated one when db_password was not set)"
  value       = module.rds.master_password
  sensitive   = true
}

output "db_security_group_id" {
  description = "Security group protecting the database"
  value       = module.rds.security_group_id
}

output "db_connection_command" {
  description = "Ready-to-run client command (get the password from db_master_password)"
  value       = module.rds.connection_command
}
