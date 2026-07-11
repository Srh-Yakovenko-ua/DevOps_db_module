output "identifier" {
  description = "Database identifier."
  value       = var.identifier
}

output "is_aurora" {
  description = "Whether an Aurora cluster was created (true) or a plain RDS instance (false)."
  value       = var.use_aurora
}

output "engine" {
  description = "Effective engine (aurora-postgresql / aurora-mysql when use_aurora is true)."
  value       = local.actual_engine
}

output "endpoint" {
  description = "Writer endpoint to connect to (cluster endpoint for Aurora, instance address for RDS)."
  value       = local.endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint. Null for a plain RDS instance."
  value       = var.use_aurora ? one(aws_rds_cluster.this[*].reader_endpoint) : null
}

output "port" {
  description = "Port the database listens on."
  value       = local.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = var.database_name
}

output "master_username" {
  description = "Master user name."
  value       = var.master_username
}

output "master_password" {
  description = "Master password (the generated one when you did not supply master_password)."
  value       = local.master_password
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the database security group."
  value       = aws_security_group.this.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Name of the parameter group in use (DB or cluster parameter group)."
  value       = var.use_aurora ? one(aws_rds_cluster_parameter_group.this[*].name) : one(aws_db_parameter_group.this[*].name)
}

output "connection_command" {
  description = "Ready-to-run client command (fill in the password from the master_password output)."
  value = var.engine == "postgres" ? (
    "PGPASSWORD=<password> psql -h ${local.endpoint} -p ${local.port} -U ${var.master_username} -d ${var.database_name}"
    ) : (
    "mysql -h ${local.endpoint} -P ${local.port} -u ${var.master_username} -p ${var.database_name}"
  )
}
