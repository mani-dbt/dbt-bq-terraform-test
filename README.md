# dbt platform Terraform Template — BigQuery

Provisions a dbt platform project with environments, jobs, and a BigQuery deployment credential using the [dbt Labs Terraform provider](https://registry.terraform.io/providers/dbt-labs/dbtcloud/latest).

---

## What gets created

| Resource | Details |
|---|---|
| Project | New (Option B) or existing (Option A) |
| Repository | GitHub via GitHub App |
| BigQuery Connections | 3 global connections — `dev_build`, `qa`, `prod` — each with a BigQuery OAuth app (Client ID/Secret) |
| Environments | 5 — `1_DEVELOPMENT` (development), `2_BUILD` (deployment), `3_QA` (`staging`), `4_PROD_CI` (deployment), `5_PROD` (`production`) |
| BigQuery Credentials | 4 dataset-scoped credentials, one per deployment environment (`build`, `qa`, `prod_ci`, `prod`; each skipped if its dataset var is null). `1_DEVELOPMENT` has none — developers connect their own BigQuery OAuth identity individually. |
| Jobs | 8 — see below |

### Jobs

| Environment | Job | Type | Trigger |
|---|---|---|---|
| `2_BUILD` | BUILD - Slim CI Job | `ci` | Pull request (defers to `2_BUILD`) |
| `2_BUILD` | BUILD - Compile Job | run | Manual |
| `2_BUILD` | BUILD - Merge Job | `merge` | On merge to `integration` (defers to `2_BUILD`) |
| `2_BUILD` | BUILD - Deploy Job | run | Manual |
| `3_QA` | QA - Deploy | run | Manual |
| `4_PROD_CI` | PROD - Slim CI Job | `ci` | Pull request to `main` (defers to `5_PROD`) |
| `5_PROD` | PROD - Compile Job | run | Manual (produces the manifest PROD CI defers against) |
| `5_PROD` | PROD - Deploy Job | run | Manual |

Branch strategy: `1_DEVELOPMENT`, `2_BUILD`, and `3_QA` build from the `integration` branch; `4_PROD_CI` and `5_PROD` build from `main`.

### State-aware orchestration (SAO)

SAO is only permitted on `staging` or `production` environments, and a dbt project allows only **one** of each type. `3_QA` holds the `staging` slot and `5_PROD` holds the `production` slot, so SAO is enabled on **QA - Deploy** and **PROD - Deploy Job**. All other jobs — including those on the `2_BUILD` (General) environment — run with `force_node_selection = true` (SAO disabled).

---

## Prerequisites

- Terraform >= 1.3
- A GitHub App installation connected to your dbt platform account
- For each of the 3 BigQuery connections (`dev_build`, `qa`, `prod`): a Google Cloud **OAuth 2.0 Client ID** (Web application type), with the redirect URI from that connection's **OAuth 2.0 Settings** section in dbt platform added as an authorized redirect URI. See [Set up BigQuery OAuth](https://docs.getdbt.com/docs/cloud/manage-access/set-up-bigquery-oauth).
- A **workload identity pool, provider, and service-account impersonation binding** already configured in GCP IAM for each of the 3 connections — Workload Identity Federation (WIF) is how the 4 deployment environments authenticate to BigQuery, and that GCP-side setup is not managed by this Terraform config.
- BigQuery Native OAuth for `1_DEVELOPMENT` requires an Enterprise-tier dbt platform account.

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
| `gcp_project_id_dev_build` / `_qa` / `_prod` | GCP project ID backing each of the 3 BigQuery connections |
| `oauth_client_id_dev_build` / `_qa` / `_prod` | OAuth 2.0 Client ID for each connection (used for WIF, and for Native OAuth on `dev_build`) |
| `oauth_client_secret_dev_build` / `_qa` / `_prod` | OAuth 2.0 Client secret for each connection |
| `build_dataset` / `qa_dataset` / `prod_ci_dataset` / `prod_dataset` | Target BigQuery dataset for each deployment environment |
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

> **Note:** `terraform destroy` will remove all managed resources, including the 3 BigQuery connections, the 4 dataset-scoped credentials, environments, jobs, and the repository link. It will **not** delete the GCP-side OAuth client or the workload identity pool/provider/impersonation binding, which live outside dbt platform and are not managed by this template. When using Option A, the project itself is also left untouched.
