# dbt platform Terraform Template — BigQuery

Provisions a dbt platform project with environments, jobs, and a BigQuery deployment credential using the [dbt Labs Terraform provider](https://registry.terraform.io/providers/dbt-labs/dbtcloud/latest).

---

## What gets created

| Resource | Details |
|---|---|
| Project | New (Option B) or existing (Option A) |
| Repository | GitHub via GitHub App |
| Environments | 5 — `1_DEVELOPMENT` (development), `2_BUILD` (deployment), `3_QA` (`staging`), `4_PROD_CI` (deployment), `5_PROD` (`production`) |
| BigQuery Credential | Dataset-scoped, linked to the project (skipped if `bigquery_dataset` is null) |
| Jobs | 7 — see below |

### Jobs

| Environment | Job | Type | Trigger |
|---|---|---|---|
| `2_BUILD` | BUILD - Slim CI Job | `ci` | Pull request (self-deferring) |
| `2_BUILD` | BUILD - Compile Job | run | Manual |
| `2_BUILD` | BUILD - Merge Job | `merge` | On merge to `integration` (defers to PROD) |
| `2_BUILD` | BUILD - Deploy Job | run | Manual |
| `3_QA` | QA - Deploy | run | Manual |
| `4_PROD_CI` | Prod - Slim CI Job | `ci` | Pull request to `main` (defers to PROD) |
| `5_PROD` | PROD - Deploy Job | run | Manual |

Branch strategy: `1_DEVELOPMENT`, `2_BUILD`, and `3_QA` build from the `integration` branch; `4_PROD_CI` and `5_PROD` build from `main`.

---

## Prerequisites

- Terraform >= 1.3
- A dbt platform account with an existing **Global Connection** for BigQuery (with a service account configured)
- A GitHub App installation connected to your dbt platform account

---

## Setup

### 1. Set the dbt platform API token

```bash
export DBT_CLOUD_TOKEN="your-dbt-cloud-service-token"
```

### 2. Configure your tfvars

Copy `example_dbt_secrets.tfvars` and fill in your values:

```bash
cp example_dbt_secrets.tfvars dbt_secrets.tfvars
```

Key fields to update:

| Variable | Description |
|---|---|
| `dbt_account_id` | Your dbt platform account ID |
| `dbt_host_url` | dbt platform API base URL (default: `https://cloud.getdbt.com/api`) |
| `connection_id` | Global BigQuery connection ID from dbt platform |
| `bigquery_dataset` | Target BigQuery dataset for deployment environments |
| `github_repo_remote_url` | GitHub repo remote URL (`git://github.com/org/repo.git`) |
| `github_installation_id` | GitHub App installation ID |

**Option A** — adopt an existing project:
```hcl
project_id = 123456
# dbt_project_name = ...   ← comment out
```

**Option B** — create a new project:
```hcl
dbt_project_name = "my-project"
# project_id = ...   ← comment out
```

#### Optional: job-trigger toggles

Set these to `true` to globally disable a trigger type across all jobs — handy during initial import or cost control. All default to `false`.

| Variable | Disables |
|---|---|
| `deactivate_jobs_pr` | Pull-request (CI) triggers |
| `deactivate_jobs_merge` | On-merge triggers |
| `deactivate_jobs_schedule` | Scheduled triggers on the deploy jobs (BUILD / QA / PROD Deploy) |

---

## Terraform commands

### Initialise

```bash
terraform init
```

### Plan

```bash
terraform plan -var-file="dbt_secrets.tfvars"
```

### Apply

```bash
terraform apply -var-file="dbt_secrets.tfvars"
```

### Destroy

```bash
terraform destroy -var-file="dbt_secrets.tfvars"
```

> **Note:** `terraform destroy` will remove all managed resources (environments, jobs, credential, repository) but will **not** delete the global BigQuery connection, which is account-scoped and not managed by this template. When using Option A, the project itself is also left untouched.
