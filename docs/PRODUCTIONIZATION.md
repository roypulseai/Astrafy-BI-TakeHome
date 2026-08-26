# Productionization Roadmap

From take-home exercise to production deployment.

## 1. Source Freshness Monitoring

Add source freshness checks to `sources.yml`:

```yaml
sources:
  - name: raw
    database: "{{ target.database }}"
    schema: recruitment_raw
    loaded_at_field: _loaded_at
    freshness:
      warn_after: { count: 24, period: hour }
      error_after: { count: 48, period: hour }
    tables:
      - name: orders_recrutement
        loaded_at_field: _loaded_at
      - name: sales_recrutement
        loaded_at_field: _loaded_at
```

Requires: BigQuery ingestion scripts to stamp `_loaded_at` on load.

## 2. CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: dbt CI
on: [pull_request, push]
jobs:
  lint-and-compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install dbt-bigquery ruff sqlfluff
      - run: dbt parse --no-partial-parse
      - run: dbt compile
      - run: ruff check .
      - run: sqlfluff lint models/ --ignore templating
```

Public repo constraints: cannot store GCP credentials in GitHub Actions. For full integration testing (against BigQuery), credentials would be stored as GitHub Secrets and injected via workload identity federation.

## 3. Incremental Materialisation

For `mart_orders` at scale:

```sql
{{
  config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    partition_by={'field': 'order_date', 'data_type': 'date', 'granularity': 'day'},
    cluster_by=['customer_id', 'order_segmentation']
  )
}}
```

**Note:** Partitioning is not applied at current scale (~3.6k orders). At production scale (millions+ rows), re-enable on `order_date`. See `docs/KNOWN_LIMITATIONS.md` for details.

Requires: `_fivetran_synced` or `order_date` based filter on incremental run.

## 4. Orchestration

```text
Option A: Airflow
  DAG: dbt_test → dbt_run → dbt_test → forecast_train → forecast_create_tvf → dashboard_refresh

Option B: dbt Cloud
  Jobs: ci_job (PR), prod_job (daily), forecast_job (weekly)

Option C: Cloud Composer
  Similar to Airflow but managed by GCP.
```

## 5. Monitoring & Alerting

| Metric | Threshold | Action |
|---|---|---|
| dbt test failures | Any ERROR | Alert Slack, block downstream |
| Source freshness | > 24 hours | Alert data engineering |
| Forecast accuracy | MAPE > 20% | Retrain model, alert analysts |
| Query cost | > $100/day | Pause BigQuery, alert finance |

## 6. Forecasting Pipeline

Current standalone script → production workflow:

```text
Step 1: dbt build (updates mart_orders + mart_orders_looker_studio view)
Step 2: Python script trains ARIMA_PLUS model
Step 3: Python script creates/updates TVFs
Step 4: Dashboard auto-refreshes (scheduled query or Looker Studio refresh)
```

## 7. Security

| Control | Implementation |
|---|---|
| Credentials | Workload Identity Federation (no keys) |
| Access control | BigQuery IAM roles (data viewer, data editor, data admin) |
| PII | None in current dataset; future: column-level security, data masking |
| Audit | BigQuery audit logs → Cloud Logging → SIEM |

## 8. Data Quality at Scale

```yaml
# dbt_project.yml
on-run-end:
  - "{{ log('dbt run completed at ' ~ run_started_at) }}"
  - "{{ analytics.log_test_results(results) }}"
```

Additional tests to add:
- `unique` on composite keys (e.g., `order_id + product_id` in sales)
- `accepted_values` with `forbidden` flag for segmentation
- `relationships` with `severity: error` for critical joins (e.g., order_id in mart must exist in staging)
