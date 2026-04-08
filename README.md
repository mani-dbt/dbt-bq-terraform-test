# dbt Cloud Terraform Template — BigQuery

Provisions a dbt Cloud project with environments, jobs, and a BigQuery deployment credential using the [dbt Labs Terraform provider](https://registry.terraform.io/providers/dbt-labs/dbtcloud/latest).

---

## What gets created

| Resource | Details |
|---|---|
| Project | New (Option B) or existing (Option A) |
| Repository | GitHub via GitHub App |
| Environments | Dev, CI (`staging`), Prod (`production`) |
| BigQuery Credential | Dataset-scoped, linked to the project |
| Jobs | CI, Merge, Parse, Daily, Adhoc |

---

## Prerequisites

- Terraform >= 1.3
- A dbt Cloud account with an existing **Global Connection** for BigQuery (with a service account configured)
- A GitHub App installation connected to your dbt Cloud account

---

## Setup

### 1. Set the dbt Cloud API token

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
| `dbt_account_id` | Your dbt Cloud account ID |
| `dbt_host_url` | dbt Cloud API base URL (default: `https://cloud.getdbt.com/api`) |
| `connection_id` | Global BigQuery connection ID from dbt Cloud |
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
