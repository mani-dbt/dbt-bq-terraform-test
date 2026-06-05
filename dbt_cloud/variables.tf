# ---------------------------------------------------------------------------
# dbt platform account
# ---------------------------------------------------------------------------

variable "dbt_account_id" {
  description = "Unique ID of your dbt platform account"
  type        = number
}

# token is supplied via the DBT_CLOUD_TOKEN environment variable

variable "dbt_host_url" {
  description = "Base URL of your dbt platform account (e.g. https://cloud.getdbt.com/api)"
  type        = string
}

# ---------------------------------------------------------------------------
# Project — leave project_id null to create a new project (Option B)
#           set project_id to adopt an existing project   (Option A)
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "ID of an existing dbt platform project to manage. Leave null to create a new project."
  type        = number
  default     = null
}

variable "dbt_project_name" {
  description = "Name for the new dbt platform project. Required when project_id is null."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------

variable "github_repo_remote_url" {
  description = "Remote URL of the GitHub repository for the github_app clone strategy (e.g. git://github.com/org/repo.git)"
  type        = string
  default     = null
}

variable "github_installation_id" {
  description = "GitHub App installation ID for the dbt platform / GitHub integration"
  type        = number
}

# ---------------------------------------------------------------------------
# BigQuery connection & credentials
# From dbt platform: Project Settings → Connection (connection_id)
# The global BigQuery connection holds the service account authentication.
# The deployment credential scopes dbt to a specific dataset per environment.
# Leave bigquery_dataset null to skip credential creation — configure in dbt platform later
# ---------------------------------------------------------------------------

variable "connection_id" {
  description = "dbt platform global connection ID for BigQuery. Leave null to configure the connection in dbt platform later."
  type        = number
  default     = null
}

variable "bigquery_dataset" {
  description = "Target BigQuery dataset dbt will write to in deployment environments (CI, Prod)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Job trigger toggles
# Set to true to globally disable a trigger type — useful during initial
# import, cost control, or when testing the configuration
# ---------------------------------------------------------------------------

variable "deactivate_jobs_pr" {
  description = "Disable PR (github_webhook / git_provider_webhook) triggers on all jobs"
  type        = bool
  default     = false
}

variable "deactivate_jobs_merge" {
  description = "Disable on_merge triggers on all jobs"
  type        = bool
  default     = false
}

variable "deactivate_jobs_schedule" {
  description = "Disable scheduled triggers on all jobs"
  type        = bool
  default     = false
}
