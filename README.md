# Astrafy BI Engineer Take-Home — dbt + BigQuery + LookML

## Overview

This is my solution for the Astrafy BI take-home challenge. It covers the full analytics stack: data ingestion, dbt transformations, a LookML semantic layer, and a Looker Studio dashboard.

```
XLSX Source Files
        │
        ▼
BigQuery Raw Tables (recruitment_raw)
        │
        ▼
dbt Staging Layer (views)
        │
        ▼
dbt Intermediate Layer (tables)
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
                   (live + PDF)

  ─────────────────────────────────────────────────────────────

  LookML Semantic Layer (Looker) — parallel deliverable
        │
        ├── orders.view.lkml     (Order Performance Explore)
        └── order_lines.view.lkml (Product Performance Explore)
```

> **Note**: LookML is for **Looker** (a separate product). The dashboard uses **Looker Studio**, which connects directly to BigQuery. The LookML files are included here as a submission deliverable.

Full architecture, layer responsibilities, and testing strategy → [`docs/architecture.md`](docs/architecture.md).

---

## About the Data

- **Orders** (`orders_recrutement`): 3,661 rows, July 2025 – Dec 2026. One row per order.
- **Sales** (`sales_recrutement`): 28,361 rows, July 2025 – Dec 2026. One row per order × product.
- **Currency**: `net_sales` is assumed to be in **CHF** (Swiss Francs). The source files don't specify a currency, and Astrafy is a Swiss company, so CHF is the natural default.

## Data Source Truth Check

The brief says the data covers Jan 2022–Dec 2023 (24 months). The actual files run **2025-07-09 → 2026-12-31** (18 months) — the end date is exactly +3 years (Dec 2023 → Dec 2026), but the start is July 2025 rather than Jan 2025, so it is not a clean uniform +3-year shift and the first 6 months of the brief's range have no counterpart in the supplied data.

I kept the dates as-is and treat the supplied files as the source of truth. The exercises explicitly ask about "the year 2026," so remapping the dates would mean redefining what "2026" refers to with no ground truth to check the mapping against — more room for confusion than it's worth. If Astrafy did intend 2022–2023, it's a one-line `DATE_SUB(..., INTERVAL 3 YEAR)` in staging — I kept staging isolated so a change like that wouldn't ripple downstream.

**Grain note:** Orders and Sales don't share a grain — joining them directly duplicates order-level metrics like `net_sales`. Handled via pre-aggregation in the intermediate layer.

---

## Objective

1. Ingest raw e-commerce data into BigQuery
2. Transform it through a layered dbt architecture (Staging → Intermediate → Mart)
3. Answer specific business questions about order volume, product behavior, and customer segmentation
4. Expose a semantic layer via LookML for business intelligence and conversational analytics
5. Support a marketing dashboard for daily performance monitoring

---

## Repository Structure

```
TH_DBT_BQ_LookML/
├── dbt_project.yml
├── ingestion/
│   ├── README.md
│   ├── load_to_bigquery.py
│   └── create_forecast_model.py
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── macros/
│   └── get_order_segment.sql
├── analyses/
│   └── exercises_1_to_3.sql
├── scripts/
│   └── keydatainsights.py        (verifies Key Data Insights claims from BQ)
├── tests/
│   ├── production/
│   └── challenge_regression/
├── lookml/
│   ├── manifest.lkml              (environment constants — no source edits needed)
│   ├── ecommerce.model.lkml
│   └── views/
├── docs/
│   ├── architecture.md
│   ├── DASHBOARD.md
│   ├── DATA_QUALITY.md
│   ├── KNOWN_LIMITATIONS.md
│   ├── PRODUCTIONIZATION.md
│   └── dbt-docs/          (open index.html for interactive docs)
├── .github/workflows/ci.yml
├── .env.example
└── Dashboard/
    └── Daily_E-Commerce_Performance.pdf
```

---

## Setup

### 1. Ingest Data

```
pip install pandas google-cloud-bigquery google-cloud-bigquery-storage openpyxl
gcloud auth application-default login
python ingestion/load_to_bigquery.py --project YOUR_PROJECT_ID
```

### 2. Configure dbt Profile

Create `~/.dbt/profiles.yml`:

```
astrafy_bi:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: YOUR_PROJECT_ID
      dataset: recruitment_analytics
      threads: 4
      location: EU
      priority: interactive
```

Test the connection: `dbt debug`

### 3. Run Pipeline

```
dbt build
dbt test
dbt docs generate
dbt docs serve
python ingestion/create_forecast_model.py  # must run after dbt build
```

---

## Exercise Answers

| Exercise                                    | Result                                                                                                                             |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1. Orders in 2026                           | **2,573**                                                                                                                          |
| 2. Orders per month (2026)                  | Jan 232; Feb 176; Mar 203; Apr 188; May 172; Jun 169; Jul 193; Aug 167; Sep 212; Oct 223; Nov 389; Dec 249                         |
| 3. Avg products/order by month (2026)       | Jan 12.57; Feb 12.62; Mar 13.07; Apr 15.10; May 14.63; Jun 14.18; Jul 13.75; Aug 14.46; Sep 13.67; Oct 13.03; Nov 10.48; Dec 11.37 |
| 4. One-row-per-order 2025–2026              | `mart_orders` with `qty_product` column (3,661 rows)                                                                               |
| 5. Segmentation (2026)                      | New 1,087; Returning 794; VIP 692                                                                                                  |
| 6. One-row-per-order 2026 with segmentation | `exercise_6_orders_segmented` view (2,573 rows)                                                                                    |
| Revenue reconciliation                      | Order-linked revenue reconciles within CHF 0.01; one orphan sales order (5361303) is excluded from order-level marts.            |

---

## Key Design Decisions

- **Grain mismatch**: Orders (1 row/order) and Sales (1 row/order × product) are reconciled through pre-aggregation in `int_order_product_summary` before joining, avoiding metric duplication.
- **Segmentation thresholds are config, not code**: New = 0 prior orders, Returning = 1–3, VIP = 4+, based on a rolling 12-month window. Thresholds are defined once as business config and mirrored in `dbt_project.yml` vars **and** `lookml/manifest.lkml` constants (`NEW_CUSTOMER_MAX_PRIOR_ORDERS`, `RETURNING_MIN/MAX_PRIOR_ORDERS`, `VIP_MIN_PRIOR_ORDERS`) — a business redefinition (e.g. VIP = 5+) is a config change, not a code rewrite. The two configs are kept in sync by a CI guard (`scripts/validate_segmentation_thresholds.py` fails the PR if they diverge) and by the runtime reconciliation test `assert_segmentation_reconciliation`. Orders before 2026-07-09 have an incomplete lookback window — use `has_complete_12_month_history` for accurate segmentation analysis.
- **`order_segmentation` vs `customer_profile`**: the former is the segment *at the time of that order*; the latter is the customer's *current* segment. This lets you distinguish "revenue from orders that were VIP at the time" from "revenue from customers who are currently VIP."
- **LookML vs Looker Studio**: LookML's `hidden: yes` only works inside Looker Explores, not Looker Studio (which connects directly to BigQuery). So the LookML semantic layer is a parallel, self-contained deliverable, and a dedicated dbt view (`mart_orders_looker_studio`) powers the actual dashboard.
- **BigQuery at scale**: partitioning isn't applied at ~3.6k orders (full scans complete in <3s) but the model is ready to add it on `order_date`; clustering is applied now on `customer_id` and `order_segmentation` for CRM lookups and segment slices.
- **Layered architecture**: Staging (no business logic) → Intermediate (reusable logic) → Marts (the only layer BI tools query) — a bug fixed once propagates everywhere downstream.

Full dashboard KPI dictionary, top-product tables, and revenue breakdowns → [`docs/DASHBOARD.md`](docs/DASHBOARD.md).

---

## Dashboard Design

Looker Studio connects directly to BigQuery. Two dbt views power the dashboard:

| View | Purpose |
| --- | --- |
| `mart_orders_looker_studio` | Order-level: KPI tiles, trends, segment tables |
| `mart_order_lines_looker_studio` | Product-level: "Top Products by Revenue / by Units Sold" tables |

**Live dashboard**: [Looker Studio](https://datastudio.google.com/s/rz5EvDxeclk)
**PDF export**: [`Dashboard/Daily_E-Commerce_Performance.pdf`](Dashboard/Daily_E-Commerce_Performance.pdf)

---

## LookML (Looker Semantic Layer)

> **Note**: LookML is for **Looker** (separate product). The dashboard uses **Looker Studio** and does not read LookML metadata.

- **`ecommerce.model.lkml`** — Model with Order Performance + Product Performance Explores
- **`views/orders.view.lkml`** — Order view with 12 measures (6 core + 6 segment-filtered), LookML-derived segmentation dimension
- **`views/order_lines.view.lkml`** — Product/order-line view with product-level metrics
- **`manifest.lkml`** — Environment constants (`GCP_PROJECT`, `BQ_DATASET`, `CONNECTION_NAME`); override per environment without editing views/models

### Deployment — Directly Deployable, Configuration Only

This is a **directly deployable** LookML project — not a template. The Looker project root is `lookml/` and `lookml/manifest.lkml` **is included in the repository** with all constants defined (with working defaults), so the project validates and runs in Looker as-is. No `.lkml` source file needs to be edited to deploy. All environment-specific values live in `lookml/manifest.lkml` as constants (using Looker's `@{...}` constant substitution; `@{GCP_PROJECT}`/`@{BQ_DATASET}` are defined in the manifest, not placeholder text):

| Constant | Default | What to configure |
|---|---|---|
| `GCP_PROJECT` | `thtask` | Target GCP project |
| `BQ_DATASET` | `recruitment_analytics` | BigQuery dataset |
| `CONNECTION_NAME` | `bigquery_connection` | Looker BigQuery connection name |
| `NEW_CUSTOMER_MAX_PRIOR_ORDERS` | `0` | Segmentation: max prior orders for New |
| `RETURNING_MIN_PRIOR_ORDERS` | `1` | Segmentation: min prior orders for Returning |
| `RETURNING_MAX_PRIOR_ORDERS` | `3` | Segmentation: max prior orders for Returning |
| `VIP_MIN_PRIOR_ORDERS` | `4` | Segmentation: min prior orders for VIP |

**Steps:**
1. Create the BigQuery connection in Looker (Admin → Connections) with the name you will use for `CONNECTION_NAME`.
2. Override constants for the target environment — in Looker's UI (Project → Settings → Constants) or by importing an environment-specific manifest that `override`s the values.
3. Deploy the project. Views resolve `sql_table_name: \`@{GCP_PROJECT}.@{BQ_DATASET}.mart_orders\`` and the model resolves `connection: "@{CONNECTION_NAME}"` from the configured constants.
4. If you change segmentation thresholds (e.g., VIP = 5+), update **both** `dbt_project.yml` vars and `manifest.lkml` constants together — drift is caught at PR time by `scripts/validate_segmentation_thresholds.py` and at runtime by `assert_segmentation_reconciliation`.

With defaults, the project is **structurally ready to be deployed and used within Looker** as the assignment requires — `lookml/` can be pushed as a Looker project and will validate/run without any file edits. Overrides are only needed when deploying to a different GCP project/dataset/connection.

### Key Design Decisions

- Primary key on `order_id` (order grain).
- Technical fields (`order_id`, `customer_id`) hidden from the user-facing field picker.
- Business descriptions on all fields, especially `order_segmentation`.
- `synonyms:` on key measures for searchability: `net_sales` → `[revenue, sales, amount, order total]`, `qty_product` → `[units, items, basket size, quantity]`, `order_segmentation` → `[customer type, buyer segment, cohort]`, `order_count` → `[order volume, number of orders, count of orders]`, `average_order_value` → `[AOV, average basket, mean order value]`.

### Segmentation Reconciliation

LookML recomputes the segmentation rule from `prior_orders_last_12_months` (New = 0, Returning = 1–3, VIP = 4+) and validates it matches the dbt-computed `order_segmentation` via `assert_segmentation_reconciliation.sql`.

### Conversational Analytics / GenAI Readiness

Descriptions + synonyms + hidden fields are necessary but not sufficient for reliable NL→SQL. The project adds explicit business semantics so an LLM does not have to infer them:

- **Clear measure names**: `average_order_value` rather than `avg_net_sales_amount`.
- **Business descriptions**: every dimension and measure has a human-readable description.
- **Hidden technical artifacts**: `order_id`, `customer_id`, and `prior_orders_last_12_months` are hidden.
- **Strategic LookML parameters** (the assignment's “strategically use parameters to guide AI”): `orders.date_granularity` (day/week/month/quarter), `orders.metric_focus` (revenue/orders/aov/basket), `orders.segment_focus` (All/New/Returning/VIP) and `order_lines.product_metric_focus` / `product_segment_focus`. Each exposes only valid business choices via `allowed_value` labels, provides context in its `description`, and hides raw `DATE_TRUNC` / measure-selection / column-filter logic. `orders.order_date_at_selected_grain` is the parameter-driven dimension AI should use for time-series instead of building its own truncation.
- **Explicit business semantics**:
  - `net_sales` = order-level net revenue (CHF); in the Orders Explore one row = one order, so `SUM(net_sales)` is safe.
  - `average_order_value` = `revenue / orders` (`total_net_sales / order_count`), not an average of averages.
  - `order_segmentation` = segment **at order time** (point-in-time, based on prior 12 months at that order); `customer_profile` = **latest/current** customer state (stable across all orders for a customer). Do not conflate them.
  - **Grain guardrails**: do not mix order-level and order-line-level measures in one query. Use the Orders Explore for order metrics and the Product Performance Explore (order_lines) for product metrics; join on `order_id` only when the question explicitly requires both grains.
  - `unique_customers` is non-additive — do not sum distinct counts across segments or time buckets; always recompute distinct.

### Looker Studio Connection

Looker Studio connects directly to BigQuery — `hidden: yes` in LookML only works in Looker Explores. So a dedicated dbt view `mart_orders_looker_studio` excludes technical keys:

| Column | Purpose |
| --- | --- |
| `order_date` | Date dimension |
| `net_sales` | Revenue metric |
| `qty_product` | Products per order |
| `product_line_count` | Product variety |
| `distinct_product_count` | Unique products |
| `order_segmentation` | New/Returning/VIP (at time of order) |
| `customer_profile` | Current segment (stable across orders) |
| `order_count` | Always `1` — SUM for total orders |
| `customer_ref` | `SHA256(customer_id)` — COUNT_DISTINCT for unique customers |
| `has_complete_12_month_history` | Whether 12-month lookback is complete |

`order_count` is always `1` so `SUM(order_count)` gives accurate totals when aggregated. `customer_ref` is a SHA256 hash so `COUNT_DISTINCT(customer_ref)` counts unique customers.

---

## Bonus: Sales Forecast (BigQuery ML + Looker Studio)

A BigQuery ML `ARIMA_PLUS` model (`sales_forecast`) trained on daily net sales from `mart_orders`. A date spine fills zero-sales days via `COALESCE`. Confidence bands floored at zero via `GREATEST(..., 0)`.

**Training details**: 539 non-zero-sales days over a 541-calendar-day range (Jul 2025 – Dec 2026); only 2 days (2026-05-19 and 2026-05-20) have no orders and are zero-filled by the date spine. `auto_arima = true` lets the model select the best ARIMA order.

**Backtesting (holdout, last H days of dataset; Dec 2026):**

Holdout = last 7 / 14 / 30 days of 2026-12-31, trained on data up to `MAX_DATE - H`. December is a high-variance holiday period; results reflect a single split, not full CV.

| Horizon | Test period | n | MAE (CHF) | RMSE (CHF) | MAPE | ME / bias (CHF) | Sum actual (CHF) | Sum forecast (CHF) |
|---|---|---|---|---|---|---|---|---|
| 7d | 2026-12-25 – 2026-12-31 | 7 | 233.58 | 288.74 | 161.67% | -224.45 | 2,626.03 | 4,197.16 |
| 14d | 2026-12-18 – 2026-12-31 | 14 | 345.62 | 382.06 | 180.38% | -306.04 | 5,233.56 | 9,518.16 |
| 30d | 2026-12-02 – 2026-12-31 | 30 | 431.84 | 517.30 | 166.26% | -375.55 | 16,771.83 | 28,038.47 |

ME negative = systematic over-forecast. High MAPE is driven by small denominators on low-sales days (e.g., 2026-12-27 actual CHF 71.55 vs forecast CHF ~600) and December volatility with only ~18 months of training data and no holiday/promotion covariates. Model is `ARIMA(0,1,1)` weekly seasonality (`AIC 7360.69`). For production, use with caution, add holiday effects, and monitor MAPE > 20% (see `docs/PRODUCTIONIZATION.md`).

**TVFs created** (by `ingestion/create_forecast_model.py`):

- `v_sales_forecast()` — 30-day forecast horizon
- `v_sales_forecast_all()` — 7, 14, 30-day horizons with `horizon` column for parameterized Looker Studio queries

**Looker Studio setup**:

1. Add BigQuery data source → **Custom Query** → project `thtask`
2. Query: `SELECT * FROM v_sales_forecast_all() WHERE series_type = 'Actual' OR (series_type = 'Forecast' AND horizon = @forecast_horizon)`
3. Create parameter: `forecast_horizon` (Number, default `30`, list: `7`, `14`, `30`)
4. Time Series Chart: dimension = `date`, metrics = `daily_net_sales` + `forecast_value`, breakdown = `series_type`

---

## Key Data Insights

### Monthly Patterns (2026)

- **November spike**: 389 orders — 2.33x the lowest month (August: 167). Likely seasonal or promotional activity, but there's no promotion data to confirm.
- **Q4 dominance**: Oct–Dec account for 861 orders (33.5% of 2026 annual volume).
- **Inverse relationship in November**: order volume peaks, but average products per order drops to 10.48 (lowest of any month).
- **April basket-size peak**: 15.10 avg products/order — highest of any month, possibly bulk or wholesale purchasing.

### Segmentation Analysis (2026)

- **New customers dominate**: 42.2% of 2026 orders come from first-time buyers (1,087 orders).
- **Repeat customer share**: 57.8% of orders come from Returning (30.9%) + VIP (26.9%) customers. No benchmark available to judge whether this is high or low relative to industry norms.
- **VIP share**: 26.9% of orders (692) come from customers who placed 4+ orders in the prior 12 months — by definition of the segmentation threshold, not a discovered loyalty signal.
- **Conversion pool**: 1,087 first-time buyers represent the largest single segment of new-to-returning transition potential. Whether this is the most impactful retention lever depends on CAC, margin, and LTV data not available in this dataset.

---

## Data Quality & Testing

**64 data tests — 62 PASS, 2 WARN (orphan `order_id` 5361303 at staging layer: 1 relationship + 1 sales→order header), 0 ERROR.**

Generic tests (`not_null`, `unique`, `accepted_values`, `relationships`) plus 10 singular SQL tests covering positive quantities, valid segments, bidirectional order/sales reconciliation (order→sales + sales→order header), dbt-vs-LookML segmentation reconciliation, and dynamic 2026 regression checks (no hardcoded numbers). Full breakdown → [`docs/architecture.md`](docs/architecture.md#testing-strategy) and [`docs/DATA_QUALITY.md`](docs/DATA_QUALITY.md).

---

## Results Summary

| Check                  | Result                                                                     |
| ----------------------- | ---------------------------------------------------------------------------- |
| Source orders          | 3,661                                                                      |
| 2025 orders            | 1,088                                                                      |
| 2026 orders            | 2,573                                                                      |
| Source sales rows      | 28,361                                                                     |
| Distinct sales orders  | 3,662 (1 orphan: 5361303)                                                  |
| Revenue reconciliation | Order-linked revenue reconciles within CHF 0.01; one orphan sales order (5361303) is excluded from order-level marts. |
| Order grain            | 1 row/order in `mart_orders`                                              |
| Segmentation           | New / Returning / VIP (rolling 12-month, thresholds as dbt vars)          |
| dbt tests              | 62 PASS, 2 WARN (orphan FK at staging: relationship + sales→order header), 0 ERROR |
| LookML                 | Model + 2 Views + 2 Explores implemented                                  |
| Dashboard              | Looker Studio live + PDF export                                           |
| Forecast               | BigQuery ML ARIMA_PLUS + date spine + multi-horizon TVF                   |

---

## Documentation

| Document | Contents |
| --- | --- |
| [`docs/architecture.md`](docs/architecture.md) | Full architecture, data lineage, layer responsibilities, testing strategy |
| [`docs/DASHBOARD.md`](docs/DASHBOARD.md) | KPI dictionary, dashboard charts, top-product tables, revenue breakdowns, forecast setup |
| [`docs/DATA_QUALITY.md`](docs/DATA_QUALITY.md) | Data quality findings with quantified impact |
| [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md) | Limitations, their impact, and mitigations |
| [`docs/PRODUCTIONIZATION.md`](docs/PRODUCTIONIZATION.md) | Production readiness roadmap |
| [`ingestion/README.md`](ingestion/README.md) | Data ingestion pipeline docs |

---

## GCP Project

| Resource          | Value                        |
| ------------------ | ----------------------------- |
| Project           | `thtask`                     |
| Raw dataset       | `recruitment_raw`            |
| Analytics dataset | `recruitment_analytics`      |
| Location          | EU                            |
| dbt profile       | `astrafy_bi` (target: `dev`) |
