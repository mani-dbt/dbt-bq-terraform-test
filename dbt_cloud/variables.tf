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

variable "dbt_project_description" {
  description = "Description for the new dbt platform project (shown in dbt Explorer). Only applies when creating a new project (project_id is null) — ignored when adopting an existing project via project_id."
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
# BigQuery connections
#
# 3 global connections are created: dev_build (1_DEVELOPMENT + 2_BUILD),
# qa (3_QA), and prod (4_PROD_CI + 5_PROD). Each uses a BigQuery OAuth app
# (Client ID/Secret) — see https://docs.getdbt.com/docs/cloud/manage-access/set-up-bigquery-oauth
# for how to create the OAuth app and its redirect URI in GCP.
#
# 1_DEVELOPMENT uses that OAuth app for Native OAuth (each developer connects
# their own BigQuery identity individually). The 4 deployment environments
# use the same OAuth app for Workload Identity Federation (WIF) instead of a
# service-account key — this requires the matching workload identity pool /
# provider / service-account impersonation binding to already exist in GCP
# IAM (not managed by this Terraform config).
# ---------------------------------------------------------------------------

variable "gcp_project_id_dev_build" {
  description = "GCP project ID for the DEV & BUILD BigQuery connection"
  type        = string
  validation {
    condition     = !startswith(var.gcp_project_id_dev_build, "TODO")
    error_message = "gcp_project_id_dev_build is still a TODO placeholder — set the real GCP project ID."
  }
}

variable "oauth_client_id_dev_build" {
  description = "OAuth 2.0 Client ID for the DEV & BUILD BigQuery connection (used for both dev Native OAuth and WIF)"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_id_dev_build, "TODO")
    error_message = "oauth_client_id_dev_build is still a TODO placeholder — set the real OAuth Client ID."
  }
}

variable "oauth_client_secret_dev_build" {
  description = "OAuth 2.0 Client secret for the DEV & BUILD BigQuery connection"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_secret_dev_build, "TODO")
    error_message = "oauth_client_secret_dev_build is still a TODO placeholder — set the real OAuth Client secret."
  }
}

variable "gcp_project_id_qa" {
  description = "GCP project ID for the QA BigQuery connection"
  type        = string
  validation {
    condition     = !startswith(var.gcp_project_id_qa, "TODO")
    error_message = "gcp_project_id_qa is still a TODO placeholder — set the real GCP project ID."
  }
}

variable "oauth_client_id_qa" {
  description = "OAuth 2.0 Client ID for the QA BigQuery connection (used for WIF)"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_id_qa, "TODO")
    error_message = "oauth_client_id_qa is still a TODO placeholder — set the real OAuth Client ID."
  }
}

variable "oauth_client_secret_qa" {
  description = "OAuth 2.0 Client secret for the QA BigQuery connection"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_secret_qa, "TODO")
    error_message = "oauth_client_secret_qa is still a TODO placeholder — set the real OAuth Client secret."
  }
}

variable "gcp_project_id_prod" {
  description = "GCP project ID for the PROD_CI & PROD BigQuery connection"
  type        = string
  validation {
    condition     = !startswith(var.gcp_project_id_prod, "TODO")
    error_message = "gcp_project_id_prod is still a TODO placeholder — set the real GCP project ID."
  }
}

variable "oauth_client_id_prod" {
  description = "OAuth 2.0 Client ID for the PROD_CI & PROD BigQuery connection (used for WIF)"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_id_prod, "TODO")
    error_message = "oauth_client_id_prod is still a TODO placeholder — set the real OAuth Client ID."
  }
}

variable "oauth_client_secret_prod" {
  description = "OAuth 2.0 Client secret for the PROD_CI & PROD BigQuery connection"
  type        = string
  sensitive   = true
  validation {
    condition     = !startswith(var.oauth_client_secret_prod, "TODO")
    error_message = "oauth_client_secret_prod is still a TODO placeholder — set the real OAuth Client secret."
  }
}

# ---------------------------------------------------------------------------
# BigQuery deployment credentials — dataset per deployment environment
# Leave any of these null to skip that credential — configure it in dbt
# platform later. 1_DEVELOPMENT has no dataset var: developers use their own
# BigQuery OAuth identity, not an admin-configured credential.
# ---------------------------------------------------------------------------

variable "build_dataset" {
  description = "Target BigQuery dataset for the 2_BUILD deployment environment"
  type        = string
  default     = null
  validation {
    condition     = var.build_dataset == null || !startswith(var.build_dataset, "TODO")
    error_message = "build_dataset is still a TODO placeholder — set the real dataset name or leave it null."
  }
  validation {
    condition     = var.build_dataset == null || can(regex("^[A-Za-z0-9_]+$", var.build_dataset))
    error_message = "build_dataset must only contain letters, numbers, and underscores — BigQuery dataset names don't allow hyphens."
  }
}

variable "qa_dataset" {
  description = "Target BigQuery dataset for the 3_QA deployment environment"
  type        = string
  default     = null
  validation {
    condition     = var.qa_dataset == null || !startswith(var.qa_dataset, "TODO")
    error_message = "qa_dataset is still a TODO placeholder — set the real dataset name or leave it null."
  }
  validation {
    condition     = var.qa_dataset == null || can(regex("^[A-Za-z0-9_]+$", var.qa_dataset))
    error_message = "qa_dataset must only contain letters, numbers, and underscores — BigQuery dataset names don't allow hyphens."
  }
}

variable "prod_ci_dataset" {
  description = "Target BigQuery dataset for the 4_PROD_CI deployment environment"
  type        = string
  default     = null
  validation {
    condition     = var.prod_ci_dataset == null || !startswith(var.prod_ci_dataset, "TODO")
    error_message = "prod_ci_dataset is still a TODO placeholder — set the real dataset name or leave it null."
  }
  validation {
    condition     = var.prod_ci_dataset == null || can(regex("^[A-Za-z0-9_]+$", var.prod_ci_dataset))
    error_message = "prod_ci_dataset must only contain letters, numbers, and underscores — BigQuery dataset names don't allow hyphens."
  }
}

variable "prod_dataset" {
  description = "Target BigQuery dataset for the 5_PROD deployment environment"
  type        = string
  default     = null
  validation {
    condition     = var.prod_dataset == null || !startswith(var.prod_dataset, "TODO")
    error_message = "prod_dataset is still a TODO placeholder — set the real dataset name or leave it null."
  }
  validation {
    condition     = var.prod_dataset == null || can(regex("^[A-Za-z0-9_]+$", var.prod_dataset))
    error_message = "prod_dataset must only contain letters, numbers, and underscores — BigQuery dataset names don't allow hyphens."
  }
}

# QA and PROD must not silently end up sharing a dataset again (that's the
# behavior this split was meant to replace).
check "distinct_deployment_datasets" {
  assert {
    condition = length(compact([
      var.build_dataset, var.qa_dataset, var.prod_ci_dataset, var.prod_dataset
      ])) == length(distinct(compact([
        var.build_dataset, var.qa_dataset, var.prod_ci_dataset, var.prod_dataset
    ])))
    error_message = "build_dataset, qa_dataset, prod_ci_dataset, and prod_dataset must all be distinct — two or more are set to the same value."
  }
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
