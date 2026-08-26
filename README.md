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

**Data source truth check**: the challenge document mentions 2022–2023 data, but the actual Excel files contain 2025–2026. I went with the files, since the pipeline should reflect what's actually in the source system rather than what the brief describes.

Orders and Sales have different grains. If you join them directly, order-level metrics like `net_sales` get duplicated. I handle this through pre-aggregation in the intermediate layer.

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
├── tests/
│   ├── production/
│   └── challenge_regression/
├── lookml/
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
| 3. Avg products/order by month              | Jan 12.57; Feb 12.62; Mar 13.07; Apr 15.10; May 14.63; Jun 14.18; Jul 13.75; Aug 14.46; Sep 13.67; Oct 13.03; Nov 10.48; Dec 11.37 |
| 4. One-row-per-order 2025–2026              | `mart_orders` with `qty_product` column (3,661 rows)                                                                               |
| 5. Segmentation (2026)                      | New 1,087; Returning 794; VIP 692                                                                                                  |
| 6. One-row-per-order 2026 with segmentation | `exercise_6_orders_segmented` view (2,573 rows)                                                                                    |
| Revenue reconciliation                      | Orders net_sales = Sales SUM(line_net_sales) within 0.01 (0 mismatches)                                                            |

---

## Key Design Decisions

- **Grain mismatch**: Orders (1 row/order) and Sales (1 row/order × product) are reconciled through pre-aggregation in `int_order_product_summary` before joining, avoiding metric duplication.
- **Segmentation thresholds are config, not code**: New = 0 prior orders, Returning = 1–3, VIP = 4+, based on a rolling 12-month window. Thresholds live in `dbt_project.yml` vars, so a business redefinition (e.g. VIP = 5+) is a one-line change, not a macro rewrite. Orders before 2026-07-09 have an incomplete lookback window — use `has_complete_12_month_history` for accurate segmentation analysis.
- **`order_segmentation` vs `customer_profile`**: the former is the segment *at the time of that order*; the latter is the customer's *current* segment. This lets you distinguish "revenue from orders that were VIP at the time" from "revenue from customers who are currently VIP."
- **LookML vs Looker Studio**: LookML's `hidden: yes` only works inside Looker Explores, not Looker Studio (which connects directly to BigQuery). So the LookML semantic layer is a parallel, self-contained deliverable, and a dedicated dbt view (`mart_orders_looker_studio`) powers the actual dashboard.
- **BigQuery at scale**: partitioning isn't applied at ~3.6k orders (full scans complete in <3s) but the model is ready to add it on `order_date`; clustering is applied now on `customer_id` and `order_segmentation` for CRM lookups and segment slices.
- **Layered architecture**: Staging (no business logic) → Intermediate (reusable logic) → Marts (the only layer BI tools query) — a bug fixed once propagates everywhere downstream.

Full dashboard KPI dictionary, top-product tables, and revenue breakdowns → [`docs/DASHBOARD.md`](docs/DASHBOARD.md).

---

## Key Data Insights

### Monthly Patterns (2026)

- **November spike**: 389 orders — 2.33x the lowest month (August: 167). Likely seasonal or promotional activity, but there's no promotion data to confirm.
- **Q4 dominance**: Oct–Dec account for 861 orders (33.5% of 2026 annual volume).
- **Inverse relationship in November**: order volume peaks, but average products per order drops to 10.48 (lowest of any month).
- **April basket-size peak**: 15.10 avg products/order — highest of any month, possibly bulk or wholesale purchasing.

### Segmentation Analysis (2026)

- **New customers dominate**: 42.2% of 2026 orders come from first-time buyers (1,087 orders).
- **Healthy retention**: 57.8% of orders come from Returning (30.9%) + VIP (26.9%) customers.
- **VIP concentration**: 26.9% of orders from VIPs (692 orders) suggests a loyal core.
- **Growth opportunity**: converting 1,087 New customers into Returning is the highest-leverage retention play.

---

## Data Quality & Testing

**62 data tests — 61 PASS, 1 WARN (orphan `order_id` 5361303 at staging layer), 0 ERROR.**

Generic tests (`not_null`, `unique`, `accepted_values`, `relationships`) plus 8 singular SQL tests covering positive quantities, valid segments, order/sales reconciliation, dbt-vs-LookML segmentation reconciliation, and dynamic 2026 regression checks (no hardcoded numbers). Full breakdown → [`docs/architecture.md`](docs/architecture.md#testing-strategy) and [`docs/DATA_QUALITY.md`](docs/DATA_QUALITY.md).

---

## Results Summary

| Check                  | Result                                                                     |
| ----------------------- | ---------------------------------------------------------------------------- |
| Source orders          | 3,661                                                                      |
| 2025 orders            | 1,088                                                                      |
| 2026 orders            | 2,573                                                                      |
| Source sales rows      | 28,361                                                                     |
| Distinct sales orders  | 3,662 (1 orphan: 5361303)                                                  |
| Revenue reconciliation | Orders net_sales = Sales SUM(line_net_sales) within 0.01 (0 mismatches)   |
| Order grain            | 1 row/order in `mart_orders`                                              |
| Segmentation           | New / Returning / VIP (rolling 12-month, thresholds as dbt vars)          |
| dbt tests              | 61 PASS, 1 WARN (orphan FK at staging), 0 ERROR                           |
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
