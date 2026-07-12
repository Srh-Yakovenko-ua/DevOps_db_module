# Aggregated outputs from all modules.

# --- S3 backend ------------------------------------------------------------
output "state_bucket_name" {
  description = "Name of the S3 bucket that stores the Terraform state"
  value       = module.s3_backend.bucket_name
}

output "dynamodb_lock_table" {
  description = "Name of the DynamoDB table used for state locking"
  value       = module.s3_backend.dynamodb_table_name
}

# --- VPC -------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# --- ECR -------------------------------------------------------------------
output "ecr_repository_url" {
  description = "URL of the ECR repository (use this as image.repository in the Helm chart)"
  value       = module.ecr.repository_url
}

# --- EKS -------------------------------------------------------------------
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "update_kubeconfig_command" {
  description = "Run this to point kubectl at the cluster"
  value       = module.eks.update_kubeconfig_command
}

# --- Jenkins ---------------------------------------------------------------
output "jenkins_url_command" {
  description = "Prints the Jenkins UI URL once its LoadBalancer is assigned"
  value       = module.jenkins.url_command
}

output "jenkins_admin_password_command" {
  description = "Prints the Jenkins admin password"
  value       = module.jenkins.admin_password_command
}

output "jenkins_job_name" {
  description = "Name of the pipeline job Jenkins creates on startup"
  value       = module.jenkins.job_name
}

# --- Argo CD ---------------------------------------------------------------
output "argocd_server_url_command" {
  description = "Prints the Argo CD UI URL once its LoadBalancer is assigned"
  value       = module.argo_cd.server_url_command
}

output "argocd_admin_password_command" {
  description = "Prints the initial Argo CD admin password (user: admin)"
  value       = module.argo_cd.admin_password_command
}

output "argocd_application_name" {
  description = "Name of the Argo CD Application that deploys Dealsbe"
  value       = module.argo_cd.application_name
}

# --- Database (modules/rds) ------------------------------------------------
output "db_endpoint" {
  description = "Writer endpoint of the database (host to connect to)"
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
  description = "Name of the initial database"
  value       = module.rds.database_name
}

output "db_username" {
  description = "Master username"
  value       = module.rds.master_username
}

output "db_password" {
  description = "Master password (generated when db_password is left null)"
  value       = module.rds.master_password
  sensitive   = true
}

output "db_is_aurora" {
  description = "Whether the database is an Aurora cluster or a plain RDS instance"
  value       = module.rds.is_aurora
}

output "db_connection_command" {
  description = "Ready-to-run psql/mysql command for connecting to the database"
  value       = module.rds.connection_command
}
