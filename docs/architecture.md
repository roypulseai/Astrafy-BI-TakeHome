# Architecture

## Pipeline Flow

```text
Source Excel Files (orders_recrutement.xlsx, sales_recrutement.xlsx)
        │
        ▼
Ingestion (ingestion/load_to_bigquery.py)
        │
        ▼
BigQuery Raw Tables (recruitment_raw.orders_recrutement, recruitment_raw.sales_recrutement)
        │
        ▼
dbt Staging Layer (stg_orders, stg_sales)
        │
        ▼
dbt Intermediate Layer (int_order_product_summary, int_order_customer_history)
        │
        ├──────────────────────────┐
        │                          │
        ▼                          ▼
  mart_orders               mart_order_lines
  (1 row/order)             (1 row/order × product)
        │                          │
        ├──────────┬───────────────┤──────────┐
        │          │               │          │
        ▼          ▼               ▼          ▼
  mart_orders_    mart_order_    Forecast  mart_product_
  looker_studio   lines_looker_  Model     summary
  (dbt view)      studio         (ARIMA_PLUS) (1 row/product)
        │         (dbt view)        │
        │              │            ▼
        │              │       TVFs (v_sales_forecast,
        │              │       v_sales_forecast_all)
        │              │            │
        └──────┬───────┘            │
               │                    │
               └────────────┬───────┘
                            ▼
                   Looker Studio Dashboard
                   (Daily E-Commerce Performance)

  ─────────────────────────────────────────────────────────────

  LookML Semantic Layer (Looker) — parallel deliverable
        │
        ├── orders.view.lkml     (Order Performance Explore)
        └── order_lines.view.lkml (Product Performance Explore)
```

## Layer Responsibilities

| Layer | Responsibility | Materialization |
|---|---|---|
| **Staging** | Source references, column renaming, date casting. No business logic. | `view` |
| **Intermediate** | Reusable business logic: product aggregation, customer history. | `table` |
| **Mart (orders)** | Canonical order-level table for BI consumption. | `table` (clustered) |
| **Mart (order lines)** | Order-line level table (1 row per order × product). Clean grain, no product aggregates. | `table` (clustered) |
| **Mart (product summary)** | Product-level pre-aggregation for Looker Studio "Top Products" tables. | `table` (clustered) |
| **Mart (LS views)** | BI presentation views for Looker Studio. Thin views over marts. | `view` |
| **LookML** | Semantic layer: dimensions, measures, explores for Looker. | N/A (LookML files) |
| **Forecasting** | BigQuery ML model training + TVF creation. | `model` + `table function` |
| **Dashboard** | Marketing-facing KPIs and visualisations. | Looker Studio |

## Data Flow for Exercises

| Exercise | Path Through Pipeline |
|---|---|
| Ex.1 (2026 count) | `stg_orders` → `mart_orders` → filter 2026 → COUNT |
| Ex.2 (monthly) | `stg_orders` → `mart_orders` → filter 2026 → GROUP BY month |
| Ex.3 (avg products) | `stg_sales` → `int_order_product_summary` → `mart_orders` → filter 2026 → AVG(qty_product) |
| Ex.4 (order table) | `stg_orders` + `stg_sales` → `int_order_product_summary` → `mart_orders` → `exercise_4_orders_with_qty` (view) |
| Ex.5 (segmentation) | `stg_orders` → `int_order_customer_history` → `get_order_segment` macro → `mart_orders` |
| Ex.6 (segmented 2026) | Full pipeline → `mart_orders` → `exercise_6_orders_segmented` (view, filter 2026) |

## Testing Strategy

```text
Generic Tests (YAML)
    ├── not_null, unique on keys
    ├── accepted_values on segmentation
    └── relationships (orphan detection, severity: warn)

Singular Tests (SQL)
    ├── assert_orders_have_positive_product_qty
    ├── assert_no_invalid_segments
    ├── assert_order_sales_match (reconciliation, tolerance 0.01)
    ├── assert_segmentation_reconciliation (dbt vs LookML segmentation)
    ├── assert_2026_order_count (dynamic: compares mart vs source)
    ├── assert_2026_segmented_order_count (dynamic: compares segmented vs source)
    ├── assert_monthly_2026_orders_reconcile (dynamic: monthly sums match)
    └── assert_order_grain (no duplicate order_ids in 2026)
```

## BigQuery Performance

| Strategy | Implementation | Rationale |
|---|---|---|
| Partitioning | Not applied — dataset too small (~3.6k orders) for measurable benefit. Full scans <3s. | At millions+ rows, re-enable on `order_date`. See Known Limitations for sandbox expiration. |
| Clustering | `customer_id`, `order_segmentation` on `mart_orders` | Co-locates blocks for CRM lookups and segment slices |
| Incremental | Discussed but not implemented (take-home scale) | At billions of rows: `unique_key='order_id'`, `incremental_strategy='merge'` |
