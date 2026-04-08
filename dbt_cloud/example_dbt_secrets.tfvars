# dbt Cloud account
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
# BigQuery connection & credentials
# connection_id:    from dbt Cloud → Project Settings → Connection
# bigquery_dataset: deployment credential target dataset created under this project
# Leave bigquery_dataset commented out to skip — configure credentials in dbt Cloud later
# ---------------------------------------------------------------------------
connection_id    = 222222
bigquery_dataset = "your_target_dataset"

# ---------------------------------------------------------------------------
# Job trigger toggles (optional)
# ---------------------------------------------------------------------------
deactivate_jobs_pr       = false
deactivate_jobs_merge    = true
deactivate_jobs_schedule = true
