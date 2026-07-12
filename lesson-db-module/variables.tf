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
  description = "S3 bucket for the Terraform state. Leave empty to derive a globally unique name from the account id."
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
  description = "CIDR blocks for the private subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
variable "ecr_scan_on_push" {
  description = "Scan images for vulnerabilities on push"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes control plane version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

# ---------------------------------------------------------------------------
# GitOps repository (the one Jenkins pushes to and Argo CD tracks)
# ---------------------------------------------------------------------------
# REQUIRED. The HTTPS URL of the Git repo that holds this project (Jenkinsfile,
# charts/, app/). Jenkins bumps charts/django-app/values.yaml here and Argo CD
# reconciles the cluster from it. Example:
#   https://github.com/<you>/DevOps_db_module.git
variable "git_repo_url" {
  description = "HTTPS URL of the Git repo Jenkins pushes to and Argo CD tracks"
  type        = string
}

variable "gitops_branch" {
  description = "Branch the pipeline pushes to and Argo CD syncs from"
  type        = string
  default     = "main"
}

# Path of THIS project inside the repo. If the repo root IS the project (this
# folder's contents at the repo root) set it to "". If the whole DevOps_db_module
# folder is the repo, the project lives under "lesson-db-module" (the default).
variable "repo_path_prefix" {
  description = "Subdirectory of the project inside the Git repo (\"\" if the project is the repo root)"
  type        = string
  default     = "lesson-db-module"
}

# ---------------------------------------------------------------------------
# GitHub credentials (used by Jenkins to push; optionally by Argo CD for a
# private repo). Prefer passing the token via the TF_VAR_github_token env var.
# ---------------------------------------------------------------------------
variable "github_username" {
  description = "GitHub username used by the pipeline to push the values bump"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token (repo scope). Set via TF_VAR_github_token."
  type        = string
  default     = ""
  sensitive   = true
}

variable "repo_private" {
  description = "Set true if the Git repo is private (Argo CD then gets a repository credential)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Jenkins
# ---------------------------------------------------------------------------
variable "jenkins_namespace" {
  description = "Namespace Jenkins runs in"
  type        = string
  default     = "jenkins"
}

variable "jenkins_chart_version" {
  description = "Version of the jenkins/jenkins Helm chart"
  type        = string
  default     = "5.9.33"
}

variable "jenkins_service_type" {
  description = "Service type for the Jenkins UI (LoadBalancer / NodePort / ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password. Empty = chart generates a random one (read it from the jenkins secret)."
  type        = string
  default     = ""
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Argo CD
# ---------------------------------------------------------------------------
variable "argocd_namespace" {
  description = "Namespace Argo CD runs in"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
  default     = "10.1.3"
}

variable "argocd_service_type" {
  description = "Service type for the Argo CD server UI/API"
  type        = string
  default     = "LoadBalancer"
}

variable "app_namespace" {
  description = "Namespace the Dealsbe application is deployed into by Argo CD"
  type        = string
  default     = "dealsbe"
}

# ---------------------------------------------------------------------------
# Cluster platform add-ons
# ---------------------------------------------------------------------------
variable "metrics_server_chart_version" {
  description = "Version of the metrics-server Helm chart. Empty installs the latest."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Database (modules/rds) - the deliverable of this theme
# ---------------------------------------------------------------------------
# These are thin pass-throughs to the reusable rds module. The module accepts
# many more inputs (see modules/rds/variables.tf and the README); the root
# exposes the ones you usually change. Switch engine or size here and the module
# derives the right parameter group family, port and defaults automatically.
variable "db_use_aurora" {
  description = "true builds an Aurora cluster, false a single RDS instance. Same module either way."
  type        = bool
  default     = false
}

variable "db_identifier" {
  description = "Base name for the database and its subnet/security/parameter groups"
  type        = string
  default     = "dealsbe-db"
}

variable "db_engine" {
  description = "Database engine: \"postgres\" or \"mysql\""
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Engine major version (for example \"16\" for postgres, \"8.0\" for mysql)"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "Instance class. Null lets the module pick db.t3.micro (RDS) / db.t3.medium (Aurora)."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Name of the initial database created inside the engine"
  type        = string
  default     = "dealsbe"
}

variable "db_username" {
  description = "Master user name"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password. Null makes the module generate a strong random one (read it from the db_password output)."
  type        = string
  default     = null
  sensitive   = true
}

variable "db_multi_az" {
  description = "Plain RDS only: run a standby in a second AZ"
  type        = bool
  default     = false
}

variable "db_aurora_instance_count" {
  description = "Aurora only: number of cluster members (1 writer, 2+ adds read replicas)"
  type        = number
  default     = 1
}
