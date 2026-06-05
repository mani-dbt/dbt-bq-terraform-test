terraform {
  required_version = ">= 1.3"

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.11"
    }
  }
}

# token is read from the DBT_CLOUD_TOKEN environment variable
provider "dbtcloud" {
  account_id = var.dbt_account_id
  host_url   = var.dbt_host_url
}

# ---------------------------------------------------------------------------
# Project — create new OR adopt an existing one
#
# Option A (existing project): set project_id in your tfvars
# Option B (new project):      leave project_id null, set dbt_project_name
# ---------------------------------------------------------------------------

resource "dbtcloud_project" "dbt_project" {
  count = var.project_id == null ? 1 : 0
  name  = var.dbt_project_name

  lifecycle {
    precondition {
      condition     = var.dbt_project_name != null
      error_message = "dbt_project_name must be provided when creating a new project (project_id is null)."
    }
  }
}

locals {
  project_id = var.project_id != null ? var.project_id : dbtcloud_project.dbt_project[0].id
}

# ---------------------------------------------------------------------------
# Repository
# ---------------------------------------------------------------------------

# to obtain the installation_id, navigate to https://<base_url>/api/v2/integrations/github/installations/
resource "dbtcloud_repository" "dbt_repository" {
  project_id             = local.project_id
  remote_url             = var.github_repo_remote_url
  github_installation_id = var.github_installation_id
  git_clone_strategy     = "github_app"
}

resource "dbtcloud_project_repository" "dbt_project_repository" {
  project_id    = local.project_id
  repository_id = dbtcloud_repository.dbt_repository.repository_id
}

# ---------------------------------------------------------------------------
# BigQuery deployment credential
# Scopes dbt to a specific dataset; connection_id links to the global BigQuery
# connection that holds the service-account auth.
# ---------------------------------------------------------------------------

resource "dbtcloud_bigquery_credential" "deployment" {
  count         = var.bigquery_dataset != null ? 1 : 0
  project_id    = local.project_id
  dataset       = var.bigquery_dataset
  num_threads   = 16
  connection_id = var.connection_id
}

locals {
  credential_id = var.bigquery_dataset != null ? dbtcloud_bigquery_credential.deployment[0].credential_id : null
}

# ---------------------------------------------------------------------------
# Environments
#
# Branch strategy:
#   Development, DEV Integration, QA  →  custom_branch = "integration"
#   Prod CI, PROD                      →  custom_branch = "main"
# ---------------------------------------------------------------------------

# Development (tag: DEV) — developer sandbox, no credential needed
resource "dbtcloud_environment" "development" {
  project_id        = local.project_id
  name              = "1_DEVELOPMENT"
  type              = "development"
  dbt_version       = "fusion-stable"
  connection_id     = var.connection_id
  use_custom_branch = true
  custom_branch     = "integration"
}

# DEV Integration (tag: General) — shared integration deployment environment
resource "dbtcloud_environment" "dev_integration" {
  project_id        = local.project_id
  name              = "2_BUILD"
  type              = "deployment"
  dbt_version       = "fusion-stable"
  connection_id     = var.connection_id
  credential_id     = local.credential_id
  use_custom_branch = true
  custom_branch     = "integration"
}

# QA (tag: Staging) — quality-assurance staging deployment
resource "dbtcloud_environment" "qa" {
  project_id        = local.project_id
  name              = "3_QA"
  type              = "deployment"
  deployment_type   = "staging"
  dbt_version       = "fusion-stable"
  connection_id     = var.connection_id
  credential_id     = local.credential_id
  use_custom_branch = true
  custom_branch     = "integration"
}

# Prod CI (tag: General) — isolated environment for production PR validation
resource "dbtcloud_environment" "prod_ci" {
  project_id        = local.project_id
  name              = "4_PROD_CI"
  type              = "deployment"
  dbt_version       = "fusion-stable"
  connection_id     = var.connection_id
  credential_id     = local.credential_id
  use_custom_branch = true
  custom_branch     = "main"
}

# PROD (tag: PROD) — production deployment; source of deferred state for all CI jobs
resource "dbtcloud_environment" "prod" {
  project_id                 = local.project_id
  name                       = "5_PROD"
  type                       = "deployment"
  deployment_type            = "production"
  dbt_version                = "fusion-stable"
  connection_id              = var.connection_id
  credential_id              = local.credential_id
  use_custom_branch          = true
  custom_branch              = "main"
  enable_model_query_history = true
}

# ---------------------------------------------------------------------------
# Jobs — DEV Integration
# ---------------------------------------------------------------------------

# Slim CI — triggered on every PR, defers to PROD for state:modified+ diffing
resource "dbtcloud_job" "dev_integration_slim_ci" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.dev_integration.environment_id
  name           = "BUILD - Slim CI Job"
  description    = "Slim CI on pull requests — builds only modified models against the integration branch"

  job_type = "ci"
  execute_steps = [
    "dbt clone --select state:modified+,config.materialized:incremental,state:old",
    "dbt build --select state:modified+"
  ]

  triggers = {
    github_webhook       = !var.deactivate_jobs_pr
    git_provider_webhook = !var.deactivate_jobs_pr
    on_merge             = false
    schedule             = false
  }

  self_deferring         = true
  compare_changes_flags  = true
  errors_on_lint_failure = true
  generate_docs          = false
}

# dbt Compile — manual; validates SQL compilation without executing
resource "dbtcloud_job" "dev_integration_compile" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.dev_integration.environment_id
  name           = "BUILD - Compile Job"
  description    = "Compiles the dbt project to validate SQL without executing any models"

  execute_steps = ["dbt compile"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = false
  }

  generate_docs = false
}

# Merge — triggered after merges to the integration branch
resource "dbtcloud_job" "dev_integration_merge" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.dev_integration.environment_id
  name           = "BUILD - Merge Job"
  description    = "CD on merge — builds modified models and regenerates docs on the integration branch"

  job_type      = "merge"
  execute_steps = ["dbt build --select state:modified+"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = !var.deactivate_jobs_merge
    schedule             = false
  }

  deferring_environment_id = dbtcloud_environment.prod.environment_id
  generate_docs            = false
}

# Deploy — manual full build on DEV Integration
resource "dbtcloud_job" "dev_integration_deploy" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.dev_integration.environment_id
  name           = "BUILD - Deploy Job"
  description    = "Full dbt build on the BUILD environment — run manually or on schedule"

  execute_steps = ["dbt build"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = !var.deactivate_jobs_schedule
  }

  generate_docs = true
}

# ---------------------------------------------------------------------------
# Jobs — QA
# ---------------------------------------------------------------------------

# Deploy — full dbt build on QA
resource "dbtcloud_job" "qa_deploy" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.qa.environment_id
  name           = "QA - Deploy"
  description    = "Full dbt build deployment on the QA staging environment"

  execute_steps = ["dbt build"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = !var.deactivate_jobs_schedule
  }

  generate_docs = true
}

# ---------------------------------------------------------------------------
# Jobs — Prod CI
# ---------------------------------------------------------------------------

# Slim CI — triggered on PRs targeting main, defers to PROD for state comparison
resource "dbtcloud_job" "prod_ci_slim_ci" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod_ci.environment_id
  name           = "Prod - Slim CI Job"
  description    = "Slim CI on pull requests to main — validates modified models against production state"

  job_type = "ci"
  execute_steps = [
    "dbt clone --select state:modified+,config.materialized:incremental,state:old",
    "dbt build --select state:modified+"
  ]

  triggers = {
    github_webhook       = !var.deactivate_jobs_pr
    git_provider_webhook = !var.deactivate_jobs_pr
    on_merge             = false
    schedule             = false
  }

  deferring_environment_id = dbtcloud_environment.prod.environment_id
  compare_changes_flags    = true
  errors_on_lint_failure   = true
  generate_docs            = false
}

# ---------------------------------------------------------------------------
# Jobs — PROD
# ---------------------------------------------------------------------------

# Deploy — full production build, triggered manually
resource "dbtcloud_job" "prod_deploy" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "PROD - Deploy Job"
  description    = "Full production deployment build — run manually or on schedule"

  execute_steps = ["dbt build"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = !var.deactivate_jobs_schedule
  }

  generate_docs        = true
  run_generate_sources = true
}
