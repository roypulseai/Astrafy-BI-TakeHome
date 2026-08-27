# Known Limitations

Documented limitations, their impact, and mitigations.

## Data

### Challenge metadata vs supplied data date discrepancy

The challenge document describes source data covering **2022–2023**, but the supplied Excel files contain data covering **2025–2026**. The exercises themselves ask for 2025 and 2026 outputs.

**Impact**: None on execution — the supplied files are the source of truth.
**Mitigation**: Original source files preserved unchanged in the repository.

### Orphan sales record

`order_id 5361303` exists in the sales table but has no matching order header. 1 orphaned sales line, CHF 47.09 revenue, 1 product unit.

**Impact**: Sales lines for this order are excluded from order-level marts. They contribute only to product-level aggregations if ever queried directly. This accounts for the CHF 47.09 difference between raw sales total (CHF 269,091.14) and mart_orders total (CHF 269,044.05).
**Mitigation**: Caught by a `relationships` test (severity: warn) in `staging.yml`. Documented in `docs/DATA_QUALITY.md`.

### Same-day order sequencing

The source data contains dates but not timestamps. 63 customer/date groups (47 distinct customers; 129 order rows, <4% of all orders) placed multiple orders on the same calendar date. Same-day orders cannot be deterministically sequenced.

**Impact**: A customer's same-day orders are excluded from each other's prior history, which can affect segmentation edge cases. For example, if a customer has two orders on the same day and neither sees the other, both may be classified as "New" when the second should be "Returning".

**Mitigation**: Deterministic tie-breaker (`ORDER BY order_date, order_id`) used for reproducibility. The lookback SQL uses `WHERE history.order_date < current_order.order_date` (strictly before), so same-day orders are correctly excluded from each other's windows. This is the best approximation without timestamps. Quantified in `docs/DATA_QUALITY.md`.

## Architecture

### Partitioning not needed at current scale

**Current state**: Clustering on `customer_id` and `order_segmentation` retained. Partitioning not applied.

**Why**: The dataset is ~3,661 orders / 28,361 order lines / ~9,200 products. Full table scans on this size complete in <3 seconds. Partitioning adds complexity with no measurable performance benefit at this scale.

**If scale grows to millions+**: Re-enable partitioning on `order_date`. The sandbox enforces a 60-day partition expiration (`default_partition_expiration_ms = 5184000000`) which would silently drop older data. In a billing-enabled project, remove it with:
```sql
ALTER SCHEMA `project.recruitment_analytics`
SET OPTIONS (default_partition_expiration_ms = NULL);
```

### Static Excel source

The source files are static take-home inputs, not a live data feed.

**Impact**: No source freshness monitoring, no incremental processing, no late-arriving data handling.
**Mitigation**: In production, automated ingestion with source freshness checks would be required. Documented in productionization roadmap.

### Forecasting outside dbt DAG

`ingestion/create_forecast_model.py` is a standalone Python script with no `ref()`-based lineage tying it to `mart_orders`.

**Impact**: If the mart schema changes, nothing automatically tells the forecast script to re-run.
**Mitigation**: Run order documented (`dbt build` first, then `python ingestion/create_forecast_model.py`). Longer-term: dbt `on-run-end` hook or a forecast-input dbt model.

### TVF recomputation cost

`v_sales_forecast_all()` is a TVF (not materialized). Every query re-runs `ML.FORECAST` three times plus re-aggregates `mart_orders`.

**Impact**: Trivial at current scale (~539 daily rows). At high traffic, would incur repeated BigQuery compute costs.
**Mitigation**: Documented that at scale, this should be materialized into a scheduled table refreshed daily.

## Forecasting

### Training data gaps

The daily sales series includes only days with orders. Days with zero sales are absent rather than present as `0`.

**Impact**: ARIMA_PLUS handles some irregularity, but a gap-free daily series is safer for daily-frequency models.
**Mitigation**: A date spine with `COALESCE(..., 0)` is implemented in `create_forecast_model.py`, filling zero-sales days before training. See `docs/DATA_QUALITY.md`.

### Limited training window

The model is trained on 541 daily points (539 non-zero) spanning ~18 months (July 2025 – December 2026). Only 2 days (2026-05-19 and 2026-05-20) have no orders.

**Impact**: Limited ability to detect annual seasonality. The model relies on ARIMA auto-detection of patterns.
**Mitigation**: Acceptable for a take-home exercise. In production, multiple years of data would be needed.

## LookML / Looker

### No live Looker instance

The LookML files are structurally correct but have not been deployed to a real Looker instance.

**Impact**: Runtime validation (connection names, BigQuery table existence) has not been tested in Looker.
**Mitigation**: Syntax validated; `sql_table_name` and `connection` are documented as environment-dependent placeholders.

### Looker Studio vs Looker

The dashboard is built in Looker Studio (connects directly to BigQuery), not Looker (which reads LookML). The `hidden: yes` LookML setting does not apply in Looker Studio.

**Impact**: Technical fields (`customer_id`, `order_id`) would be visible if connecting to the raw table.
**Mitigation**: Dedicated `mart_orders_looker_studio` dbt view excludes technical fields and adds `order_count`/`customer_ref` for KPI accuracy.

## CI/CD

### Public repository constraints

The repository is public. BigQuery credentials cannot be stored in GitHub Actions.

**Impact**: CI pipeline cannot run `dbt build` or `dbt test` against a live BigQuery instance.
**Mitigation**: CI validates syntax and compilation only (`dbt parse`, `dbt compile`). Full integration tests require local or CI-CD runner with GCP credentials.
