terraform {
  required_version = ">= 1.3"

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = ">= 1.12.5, < 2.0"
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
  count       = var.project_id == null ? 1 : 0
  name        = var.dbt_project_name
  description = var.dbt_project_description

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
# BigQuery connections
#
# 3 global connections, each with a BigQuery OAuth app (Client ID/Secret)
# registered on it. Deployment environments authenticate via Workload
# Identity Federation (WIF); the 1_DEVELOPMENT environment uses the same
# OAuth app for Native OAuth, where each developer individually connects
# their own BigQuery identity from their dbt platform profile.
#
#   dev_build (DEV & BUILD) -> 1_DEVELOPMENT (Native OAuth) + 2_BUILD (WIF)
#   qa        (QA)          -> 3_QA (WIF)
#   prod      (PROD_CI & PROD) -> 4_PROD_CI + 5_PROD (WIF)
#
# NOTE: the dbt platform API currently still requires service-account fields
# to be populated even when deployment_env_auth_type = "external-oauth-wif".
# Per dbt's docs these values don't need to be real when WIF is used ("they
# can be N/A"), so placeholders are used below instead of a real key.
# ---------------------------------------------------------------------------

locals {
  bigquery_sa_placeholder = {
    private_key_id              = "N/A"
    private_key                 = "N/A"
    client_email                = "N/A"
    client_id                   = "N/A"
    auth_uri                    = "N/A"
    token_uri                   = "N/A"
    auth_provider_x509_cert_url = "N/A"
    client_x509_cert_url        = "N/A"
  }
}

resource "dbtcloud_global_connection" "dev_build" {
  name = "DEV & BUILD - BigQuery"
  bigquery = merge(local.bigquery_sa_placeholder, {
    gcp_project_id           = var.gcp_project_id_dev_build
    application_id           = var.oauth_client_id_dev_build
    application_secret       = var.oauth_client_secret_dev_build
    deployment_env_auth_type = "external-oauth-wif"
    use_latest_adapter       = true
  })
}

resource "dbtcloud_global_connection" "qa" {
  name = "QA - BigQuery"
  bigquery = merge(local.bigquery_sa_placeholder, {
    gcp_project_id           = var.gcp_project_id_qa
    application_id           = var.oauth_client_id_qa
    application_secret       = var.oauth_client_secret_qa
    deployment_env_auth_type = "external-oauth-wif"
    use_latest_adapter       = true
  })
}

resource "dbtcloud_global_connection" "prod" {
  name = "PROD_CI & PROD - BigQuery"
  bigquery = merge(local.bigquery_sa_placeholder, {
    gcp_project_id           = var.gcp_project_id_prod
    application_id           = var.oauth_client_id_prod
    application_secret       = var.oauth_client_secret_prod
    deployment_env_auth_type = "external-oauth-wif"
    use_latest_adapter       = true
  })
}

# ---------------------------------------------------------------------------
# BigQuery deployment credentials — dataset-scoped per deployment environment
# 1_DEVELOPMENT gets none: developers connect their own BigQuery OAuth
# identity individually (Account settings -> Credentials), which admin-side
# Terraform config cannot do on a user's behalf.
# ---------------------------------------------------------------------------

resource "dbtcloud_bigquery_credential" "build" {
  count         = var.build_dataset != null ? 1 : 0
  project_id    = local.project_id
  dataset       = var.build_dataset
  num_threads   = 16
  connection_id = dbtcloud_global_connection.dev_build.id
}

resource "dbtcloud_bigquery_credential" "qa" {
  count         = var.qa_dataset != null ? 1 : 0
  project_id    = local.project_id
  dataset       = var.qa_dataset
  num_threads   = 16
  connection_id = dbtcloud_global_connection.qa.id
}

resource "dbtcloud_bigquery_credential" "prod_ci" {
  count         = var.prod_ci_dataset != null ? 1 : 0
  project_id    = local.project_id
  dataset       = var.prod_ci_dataset
  num_threads   = 16
  connection_id = dbtcloud_global_connection.prod.id
}

resource "dbtcloud_bigquery_credential" "prod" {
  count         = var.prod_dataset != null ? 1 : 0
  project_id    = local.project_id
  dataset       = var.prod_dataset
  num_threads   = 16
  connection_id = dbtcloud_global_connection.prod.id
}

locals {
  build_credential_id   = var.build_dataset != null ? dbtcloud_bigquery_credential.build[0].credential_id : null
  qa_credential_id      = var.qa_dataset != null ? dbtcloud_bigquery_credential.qa[0].credential_id : null
  prod_ci_credential_id = var.prod_ci_dataset != null ? dbtcloud_bigquery_credential.prod_ci[0].credential_id : null
  prod_credential_id    = var.prod_dataset != null ? dbtcloud_bigquery_credential.prod[0].credential_id : null
}

# ---------------------------------------------------------------------------
# Environments
#
# Branch strategy:
#   Development, DEV Integration, QA  →  custom_branch = "integration"
#   Prod CI, PROD                      →  custom_branch = "main"
# ---------------------------------------------------------------------------

# Development (tag: DEV) — developer sandbox; BigQuery Native OAuth via the
# dev_build connection's OAuth app. Each developer connects their own
# BigQuery identity individually in their profile — no credential_id here.
resource "dbtcloud_environment" "development" {
  project_id        = local.project_id
  name              = "1_DEVELOPMENT"
  type              = "development"
  dbt_version       = "fusion-stable"
  connection_id     = dbtcloud_global_connection.dev_build.id
  use_custom_branch = true
  custom_branch     = "integration"
}

# DEV Integration (tag: General) — shared integration deployment environment
# BigQuery via Workload Identity Federation (dev_build connection)
resource "dbtcloud_environment" "dev_integration" {
  project_id        = local.project_id
  name              = "2_BUILD"
  type              = "deployment"
  dbt_version       = "fusion-stable"
  connection_id     = dbtcloud_global_connection.dev_build.id
  credential_id     = local.build_credential_id
  use_custom_branch = true
  custom_branch     = "integration"
}

# QA (tag: Staging) — quality-assurance staging deployment
# BigQuery via Workload Identity Federation (qa connection)
resource "dbtcloud_environment" "qa" {
  project_id        = local.project_id
  name              = "3_QA"
  type              = "deployment"
  deployment_type   = "staging"
  dbt_version       = "fusion-stable"
  connection_id     = dbtcloud_global_connection.qa.id
  credential_id     = local.qa_credential_id
  use_custom_branch = true
  custom_branch     = "integration"
}

# Prod CI (tag: General) — isolated environment for production PR validation
# BigQuery via Workload Identity Federation (prod connection)
resource "dbtcloud_environment" "prod_ci" {
  project_id        = local.project_id
  name              = "4_PROD_CI"
  type              = "deployment"
  dbt_version       = "fusion-stable"
  connection_id     = dbtcloud_global_connection.prod.id
  credential_id     = local.prod_ci_credential_id
  use_custom_branch = true
  custom_branch     = "main"
}

# PROD (tag: PROD) — production deployment; source of deferred state for all CI jobs
# BigQuery via Workload Identity Federation (prod connection)
resource "dbtcloud_environment" "prod" {
  project_id                 = local.project_id
  name                       = "5_PROD"
  type                       = "deployment"
  deployment_type            = "production"
  dbt_version                = "fusion-stable"
  connection_id              = dbtcloud_global_connection.prod.id
  credential_id              = local.prod_credential_id
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

  deferring_environment_id = dbtcloud_environment.dev_integration.environment_id
  compare_changes_flags    = true
  errors_on_lint_failure   = true
  generate_docs            = false
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

  # SAO requires a staging/production environment; BUILD is neither, so disable it
  force_node_selection = true

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

  deferring_environment_id = dbtcloud_environment.dev_integration.environment_id
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

  # SAO requires a staging/production environment; BUILD is neither, so disable it
  force_node_selection = true

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

  # SAO disabled for now — re-enable cost_optimization_features when dbt State is turned on.
  # cost_optimization_features is set explicitly (not omitted) so Terraform keeps managing
  # it instead of leaving it computed, which is what caused the drift in the past.
  cost_optimization_features = []
  force_node_selection       = true

  generate_docs = true
}

# ---------------------------------------------------------------------------
# Jobs — Prod CI
# ---------------------------------------------------------------------------

# Slim CI — triggered on PRs targeting main, defers to PROD for state comparison
resource "dbtcloud_job" "prod_ci_slim_ci" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod_ci.environment_id
  name           = "PROD - Slim CI Job"
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

  # SAO disabled for now — re-enable cost_optimization_features when dbt State is turned on.
  # cost_optimization_features is set explicitly (not omitted) so Terraform keeps managing
  # it instead of leaving it computed, which is what caused the drift in the past.
  cost_optimization_features = []
  force_node_selection       = true

  generate_docs        = true
  run_generate_sources = true
}

# dbt Compile — manual; produces the production manifest that PROD CI defers against
resource "dbtcloud_job" "prod_compile" {
  project_id     = local.project_id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "PROD - Compile Job"
  description    = "Compiles the dbt project to validate SQL without executing any models"

  execute_steps = ["dbt compile"]

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    on_merge             = false
    schedule             = false
  }

  # Compile does not build models, so SAO is not applicable
  force_node_selection = true

  generate_docs = false
}
