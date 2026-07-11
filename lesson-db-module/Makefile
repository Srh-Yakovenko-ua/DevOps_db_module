# Makefile for the lesson-db-module project (reusable RDS/Aurora Terraform module).
# Run `make help` for the available targets.
#
# Account agnostic: the state bucket name is derived from the current AWS
# account id, so anyone can deploy into their own account without edits.

PROJECT ?= lesson-db-module
REGION  ?= us-west-2

BACKEND_CONFIG = -backend-config="bucket=$(PROJECT)-tfstate-$$(aws sts get-caller-identity --query Account --output text)" -backend-config="region=$(REGION)"
TF_VARS        = -var="aws_region=$(REGION)" -var="project=$(PROJECT)"

.DEFAULT_GOAL := help
.PHONY: help fmt validate init bootstrap plan apply destroy clean db-info db-endpoint db-password

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate the configuration without touching AWS
	terraform init -backend=false
	terraform validate

init: ## Initialize Terraform against the remote backend
	terraform init $(BACKEND_CONFIG)

bootstrap: ## First run: create the S3/DynamoDB backend, migrate state, then apply
	terraform init -backend=false
	terraform apply -target=module.s3_backend -auto-approve $(TF_VARS)
	terraform init -migrate-state -force-copy $(BACKEND_CONFIG)
	terraform apply -auto-approve $(TF_VARS)

plan: ## Show the execution plan
	terraform plan $(TF_VARS)

apply: ## Create or update the infrastructure
	terraform apply $(TF_VARS)

# Aurora example: make apply-aurora
apply-aurora: ## Apply with Aurora enabled (use_aurora=true)
	terraform apply $(TF_VARS) -var="use_aurora=true"

destroy: ## Destroy everything (database and VPC first, then the state backend)
	terraform destroy -target=module.rds -target=module.vpc -auto-approve $(TF_VARS)
	terraform state pull > terraform.tfstate
	terraform init -reconfigure -backend=false -input=false
	terraform destroy -auto-approve $(TF_VARS)
	rm -f terraform.tfstate terraform.tfstate.backup

clean: ## Remove local Terraform working files
	rm -rf .terraform terraform.tfstate terraform.tfstate.backup

# ---------------------------------------------------------------------------
# Handy lookups after apply
# ---------------------------------------------------------------------------
db-info: ## Print endpoint, port, user and database name
	@echo "endpoint: $$(terraform output -raw db_endpoint)"
	@echo "port:     $$(terraform output -raw db_port)"
	@echo "user:     $$(terraform output -raw db_username)"
	@echo "database: $$(terraform output -raw db_name)"

db-endpoint: ## Print the database endpoint
	@terraform output -raw db_endpoint; echo

db-password: ## Print the generated master password
	@terraform output -raw db_master_password; echo
