# dbt platform account
dbt_account_id = 12345
dbt_host_url   = "https://cloud.getdbt.com/api"
# export DBT_CLOUD_TOKEN="your-token"  ← set token via env var, never in this file

# ---------------------------------------------------------------------------
# Project — choose Option A (existing) or Option B (new), comment out the other
# ---------------------------------------------------------------------------

# Option A: adopt an existing project
project_id = 123456

# Option B: create a new project
#dbt_project_name = "test-project"

# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------
github_repo_remote_url = "git://github.com/your-org/your-repo.git"
# to obtain the installation_id: https://cloud.getdbt.com/api/v2/integrations/github/installations/
github_installation_id = 123456

# ---------------------------------------------------------------------------
# BigQuery connections
# 3 connections are created: dev_build, qa, prod. Each needs a GCP project ID
# and an OAuth 2.0 Client ID/Secret (see docs.getdbt.com/docs/cloud/manage-access/set-up-bigquery-oauth
# for how to create the OAuth app in GCP). Deployment environments use the
# OAuth app for Workload Identity Federation; 1_DEVELOPMENT uses it for
# Native OAuth (each developer connects their own identity in the UI).
# ---------------------------------------------------------------------------
gcp_project_id_dev_build      = "your-gcp-project-id"
oauth_client_id_dev_build     = "your-oauth-client-id.apps.googleusercontent.com"
oauth_client_secret_dev_build = "your-oauth-client-secret"

gcp_project_id_qa      = "your-gcp-project-id"
oauth_client_id_qa     = "your-oauth-client-id.apps.googleusercontent.com"
oauth_client_secret_qa = "your-oauth-client-secret"

gcp_project_id_prod      = "your-gcp-project-id"
oauth_client_id_prod     = "your-oauth-client-id.apps.googleusercontent.com"
oauth_client_secret_prod = "your-oauth-client-secret"

# BigQuery deployment credentials — dataset per deployment environment
# Leave commented out to skip — configure credentials in dbt platform later
build_dataset   = "your_build_dataset"
qa_dataset      = "your_qa_dataset"
prod_ci_dataset = "your_prod_ci_dataset"
prod_dataset    = "your_prod_dataset"

# ---------------------------------------------------------------------------
# Job trigger toggles (optional)
# ---------------------------------------------------------------------------
deactivate_jobs_pr       = false
deactivate_jobs_merge    = true
deactivate_jobs_schedule = true
