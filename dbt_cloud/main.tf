terraform {
  required_version = ">= 1.3"

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.8"
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
  # Single reference used by every downstream resource
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
# Deployment credential
# Created under this project so it is always correctly scoped.
# BigQuery auth (service account) lives in the global connection;
# the credential here scopes dbt to a specific dataset.
# ---------------------------------------------------------------------------

resource "dbtcloud_bigquery_credential" "deployment" {
  count       = var.bigquery_dataset != null ? 1 : 0
  project_id  = local.project_id
  dataset     = var.bigquery_dataset
  num_threads = 16
}

locals {
  credential_id = var.bigquery_dataset != null ? dbtcloud_bigquery_credential.deployment[0].credential_id : null
}

# ---------------------------------------------------------------------------
# Environments
# ---------------------------------------------------------------------------

# Dev — development type, no credential (uses global connection)
resource "dbtcloud_environment" "dev" {
  project_id    = local.project_id
  name          = "Dev"
  type          = "development"
  connection_id = var.connection_id
}

# CI — isolated deployment environment used exclusively by CI jobs
# Defers to Prod so slim CI diffs against the latest production manifest
resource "dbtcloud_environment" "ci" {
  project_id      = local.project_id
  name            = "CI"
  type            = "deployment"
  deployment_type = "staging"
  connection_id   = var.connection_id
  credential_id   = local.credential_id
}

# Prod — production deployment environment
# model query history enabled here only, for production observability
resource "dbtcloud_environment" "prod" {
  project_id                 = local.project_id
  name                       = "Prod"
  type                       = "deployment"
  deployment_type            = "production"
  connection_id              = var.connection_id
  credential_id              = local.credential_id
  enable_model_query_history = true
}

# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

# CI job — triggered on every PR, runs on the CI environment
# Defers to Prod so only modified models are built (slim CI)
resource "dbtcloud_job" "ci" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.ci.environment_id
  name           = "CI"
  description    = "Slim CI triggered on pull requests — builds only modified models"

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

# Merge/CD job — triggered after every merge to main
# Runs on Prod, defers to Prod for state:modified+ efficiency
resource "dbtcloud_job" "merge" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "Merge"
  description    = "CD triggered on merges to main — builds modified models and regenerates docs"

  job_type      = "merge"
  execute_steps = ["dbt build --select state:modified+"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = !var.deactivate_jobs_merge
    schedule             = false
  }

  deferring_environment_id = dbtcloud_environment.prod.environment_id
  generate_docs            = true
}


# Parse job — merge-triggered, refreshes the deferred manifest immediately
# after each merge so the next CI run diffs against a fresh baseline
resource "dbtcloud_job" "parse" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "Parse"
  description    = "Refreshes the deferred manifest after each merge to keep slim CI accurate"

  job_type      = "merge"
  execute_steps = ["dbt parse"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = !var.deactivate_jobs_merge
    schedule             = false
  }

  deferring_environment_id = dbtcloud_environment.prod.environment_id
  generate_docs            = false
}

# Daily scheduled job — builds all models tagged :daily
resource "dbtcloud_job" "daily" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "Daily"
  description    = "Nightly full build of all models tagged :daily"

  execute_steps = ["dbt build -s tag:daily"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = !var.deactivate_jobs_schedule
  }

  generate_docs        = true
  run_generate_sources = true

  schedule_type  = "days_of_week"
  schedule_days  = [0, 1, 2, 3, 4, 5, 6]
  schedule_hours = [2]
}

# Adhoc job — no triggers, run manually as needed
resource "dbtcloud_job" "adhoc" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "Adhoc"
  description    = "One-off full build, triggered manually"

  execute_steps = ["dbt build"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = false
  }

  generate_docs = false
}
