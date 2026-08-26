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

---

## About the Data

- **Orders** (`orders_recrutement`): 3,661 rows, July 2025 – Dec 2026. One row per order.
- **Sales** (`sales_recrutement`): 28,361 rows, July 2025 – Dec 2026. One row per order × product.

The challenge document mentions 2022–2023 data, but the actual Excel files contain 2025–2026. I went with the files.

One thing worth calling out: Orders and Sales have different grains. If you join them directly, order-level metrics like `net_sales` get duplicated. I handle this through pre-aggregation in the intermediate layer.

---

## Objective

1. Ingest raw e-commerce data into BigQuery
2. Transform it through a layered dbt architecture (Staging → Intermediate → Mart)
3. Answer specific business questions about order volume, product behavior, and customer segmentation
4. Expose a semantic layer via LookML for business intelligence and conversational analytics
5. Support a marketing dashboard for daily performance monitoring

---

## Repository Structure

```text
TH_DBT_BQ_LookML/
├── dbt_project.yml
├── ingestion/
│   ├── README.md
│   ├── load_to_bigquery.py
│   └── create_forecast_model.py
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── stg_orders.sql
│   │   ├── stg_sales.sql
│   │   └── staging.yml
│   ├── intermediate/
│   │   ├── int_order_product_summary.sql
│   │   ├── int_order_customer_history.sql
│   │   └── intermediate.yml
│   └── marts/
│       ├── mart_orders.sql
│       ├── mart_order_lines.sql
│       ├── mart_product_summary.sql
│       ├── mart_orders_looker_studio.sql
│       ├── mart_order_lines_looker_studio.sql
│       ├── marts.yml
│       ├── exercise_4_orders_with_qty.sql
│       └── exercise_6_orders_segmented.sql
├── macros/
│   └── get_order_segment.sql
├── analyses/
│   └── exercises_1_to_3.sql
├── tests/
│   ├── production/
│   │   ├── assert_order_sales_match.sql
│   │   ├── assert_orders_have_positive_product_qty.sql
│   │   ├── assert_no_invalid_segments.sql
│   │   └── assert_segmentation_reconciliation.sql
│   └── challenge_regression/
│       ├── assert_2026_order_count.sql
│       ├── assert_2026_segmented_order_count.sql
│       ├── assert_monthly_2026_orders_reconcile.sql
│       └── assert_order_grain.sql
├── lookml/
│   ├── ecommerce.model.lkml
│   └── views/
│       ├── orders.view.lkml
│       └── order_lines.view.lkml
├── docs/
│   ├── KNOWN_LIMITATIONS.md
│   ├── DATA_QUALITY.md
│   ├── architecture.md
│   ├── PRODUCTIONIZATION.md
│   └── dbt-docs/
│       ├── index.html          (open in browser for interactive docs)
│       ├── manifest.json
│       └── catalog.json
├── .github/workflows/ci.yml
├── .env.example
└── Dashboard/
    └── Daily_E-Commerce_Performance.pdf
```

---

## Setup

### 1. Ingest Data

```bash
pip install pandas google-cloud-bigquery google-cloud-bigquery-storage openpyxl
gcloud auth application-default login
python ingestion/load_to_bigquery.py --project YOUR_PROJECT_ID
```

### 2. Configure dbt Profile

Create `~/.dbt/profiles.yml`:

```yaml
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

```bash
dbt build
dbt test
dbt docs generate
dbt docs serve
python ingestion/create_forecast_model.py  # must run after dbt build
```

---

## Architecture

### Layered Architecture

Each layer has a single responsibility:

- **Staging** — renames columns, casts types, parses dates. No business logic. If the source changes a date format, there's one file to update.
- **Intermediate** — business logic that's reused across marts but isn't report-ready on its own.
- **Marts** — the only layer BI tools should query. A bug here gets fixed once and propagates everywhere.

### Grain

The canonical analytical model is one row per order. The source data has two different grains:

- **Orders**: one row per order
- **Sales**: one row per order × product

Joining them without pre-aggregation duplicates order-level metrics.

### Staging Layer

Source references, column renaming, data-type casting. No business logic.

### Intermediate Layer

- **`int_order_product_summary`** — Aggregates product lines to order grain (total qty, line count, distinct products).
- **`int_order_customer_history`** — Rolling 12-month prior order count for each customer at each order date, plus `has_complete_12_month_history`.

`qty_product` is `SUM(sales.qty)` — total units per order, not distinct product count. The 12-month lookback uses a self-join so it captures only the trailing window (excluding the current order), not a cumulative total.

### Mart

**`mart_orders`** (1 row per order):
- Order attributes (`order_id`, `customer_id`, `order_date`, `net_sales`)
- Product summary (`qty_product`, `product_line_count`, `distinct_product_count`)
- Segmentation (`prior_orders_last_12_months`, `has_complete_12_month_history`, `order_segmentation`, `customer_profile`)

**`mart_order_lines`** (1 row per order × product):
- Order-line metrics (`quantity`, `net_sales`, `revenue_per_unit`)
- Order-level attributes for segmentation and filtering

**`mart_product_summary`** (1 row per product):
- Pre-aggregated product metrics: total revenue, units, order count, customer count
- Segment breakdown (New/Returning/VIP revenue)
- Monthly averages and active month count

Two thin Looker Studio views expose clean column names:
- `mart_orders_looker_studio` — order-level (KPI tiles, trends, segment tables)
- `mart_order_lines_looker_studio` — order-line grain ("Top Products" tables, aggregated at query time)
- `mart_product_summary` — product-level ("Top Products" tables, pre-aggregated)

Exercises 4 and 6 are almost identical — both order-grain, both need `qty_product`, and Ex.6 is a strict subset (2026 only). Rather than duplicate logic, I built one mart and added thin views (`exercise_4_orders_with_qty`, `exercise_6_orders_segmented`) for the exact deliverables.

`order_segmentation` changes per order as the customer places more orders. `customer_profile` is the customer's *current* segment based on their latest order. This lets you query "total revenue from customers who are *currently* VIP" vs. "revenue from orders that were VIP *at the time*."

The `COALESCE(..., 0)` on product fields is a safety net — if a future order arrives with zero product lines, the LEFT JOIN produces NULL instead of 0.

### Segmentation Thresholds

Based on **rolling 12-month** prior order count:

| Segment | Prior Orders (12 months) |
|---|---|
| New | 0 |
| Returning | 1–3 |
| VIP | 4+ |

Thresholds are `dbt_project.yml` vars, not hardcoded in the macro — if the business redefines "VIP" as 5+ orders, that's a one-line config change.

> **Heads up**: Orders before 2026-07-09 have an incomplete lookback window. Use `has_complete_12_month_history` for accurate segmentation analysis.

### BigQuery at Scale

- **Partitioning**: Not applied — ~3.6k orders is too small to benefit. Full scans complete in <3 seconds. At millions of rows, re-enable on `order_date`.
- **Clustering**: By `customer_id` and `order_segmentation` — co-locates storage for CRM lookups and segment slices.
- **Incremental models**: At scale, use `materialized='incremental'` with `unique_key='order_id'`.
- **Forecast TVF cost**: `v_sales_forecast_all()` is a TVF — every query re-runs `ML.FORECAST`. At high traffic, materialize into a scheduled table.

---

## Exercise Answers

| Exercise | Result |
|---|---|
| 1. Orders in 2026 | **2,573** |
| 2. Orders per month (2026) | Jan 232; Feb 176; Mar 203; Apr 188; May 172; Jun 169; Jul 193; Aug 167; Sep 212; Oct 223; Nov 389; Dec 249 |
| 3. Avg products/order by month | Jan 12.57; Feb 12.62; Mar 13.07; Apr 15.10; May 14.63; Jun 14.18; Jul 13.75; Aug 14.46; Sep 13.67; Oct 13.03; Nov 10.48; Dec 11.37 |
| 4. One-row-per-order 2025–2026 | `mart_orders` with `qty_product` column (3,661 rows) |
| 5. Segmentation (2026) | New 1,087; Returning 794; VIP 692 |
| 6. One-row-per-order 2026 with segmentation | `exercise_6_orders_segmented` view (2,573 rows) |
| Revenue reconciliation | Orders net_sales = Sales SUM(line_net_sales) within 0.01 (0 mismatches) |

---

## LookML (Looker Semantic Layer)

> **Note**: LookML is for **Looker** (separate product). The dashboard uses **Looker Studio** and does not read LookML metadata.

- **`ecommerce.model.lkml`** — Model with Order Performance + Product Performance Explores
- **`views/orders.view.lkml`** — Order view with 12 measures (6 core + 6 segment-filtered), LookML-derived segmentation dimension
- **`views/order_lines.view.lkml`** — Product/order-line view with product-level metrics

### Key Design Decisions

- Primary key on `order_id` (order grain).
- Technical fields (`order_id`, `customer_id`) hidden from the user-facing field picker.
- Business descriptions on all fields, especially `order_segmentation`.
- `synonyms:` on key measures for searchability: `net_sales` has `[revenue, sales, amount, order total]`, `qty_product` has `[units, items, basket size, quantity]`, `order_segmentation` has `[customer type, buyer segment, cohort]`, `order_count` has `[order volume, number of orders, count of orders]`, `average_order_value` has `[AOV, average basket, mean order value]`.

### Segmentation Reconciliation

LookML recomputes the segmentation rule from `prior_orders_last_12_months` (New = 0, Returning = 1-3, VIP = 4+) and validates it matches the dbt-computed `order_segmentation` via `assert_segmentation_reconciliation.sql`.

### Conversational Analytics / GenAI Readiness

- **Clear measure names**: `average_order_value` rather than `avg_net_sales_amount`.
- **Business descriptions**: Every dimension and measure has a human-readable description.
- **Hidden technical artifacts**: `order_id`, `customer_id`, and `prior_orders_last_12_months` are hidden.

### Looker Studio Connection

Looker Studio connects directly to BigQuery — `hidden: yes` in LookML only works in Looker Explores. So I built a dedicated dbt view `mart_orders_looker_studio` that excludes technical keys:

| Column | Purpose |
|---|---|
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

## Dashboard Design (Part 3)

Looker Studio connects directly to BigQuery. Two dbt views power the dashboard:

| View | Purpose |
|---|---|
| `mart_orders_looker_studio` | Order-level: KPI tiles, trends, segment tables |
| `mart_order_lines_looker_studio` | Product-level: "Top Products by Revenue / by Units Sold" tables |

**Live dashboard**: [Looker Studio](https://datastudio.google.com/s/uomZI0GAGhM)
**PDF export**: [`Dashboard/Daily_E-Commerce_Performance.pdf`](Dashboard/Daily_E-Commerce_Performance.pdf)

### KPI Dictionary

| KPI | Definition | Grain | Source |
|---|---|---|---|
| Orders | Count of orders | Order | `SUM(order_count)` |
| Revenue | Net sales at order level | Order | `SUM(net_sales)` |
| Customers | Distinct customers (SHA256 hash) | Customer | `COUNT_DISTINCT(customer_ref)` |
| AOV | Revenue / Orders | Order | Calculated field |
| Products/order | Total product quantity / Orders | Order | `SUM(qty_product) / SUM(order_count)` |
| Order Segmentation | Rolling 12-month customer history at time of order | Order | `order_segmentation` dimension (New/Returning/VIP) |
| Customer Profile | Customer's current segment based on latest order | Order | `customer_profile` dimension (New/Returning/VIP) |

### KPI Tiles

| KPI | Looker Studio Formula | Validated Value |
|---|---|---|
| Net Sales | `SUM(net_sales)` | $269,044.05 |
| Orders | `SUM(order_count)` | 3,661 |
| Average Order Value | `SUM(net_sales) / SUM(order_count)` | $73.49 |
| Products Sold | `SUM(qty_product)` | 47,728 |
| Avg Products per Order | `SUM(qty_product) / SUM(order_count)` | 13.04 |
| Unique Customers | `COUNT_DISTINCT(customer_ref)` | 1,716 |

> Products Sold is 47,728 (not 47,729) because the orphan order_id 5361303 with 1 unit is excluded from the mart.

### Charts

1. **Net Sales trend** (daily) — revenue patterns and anomalies
2. **Orders trend** (daily) — order volume changes
3. **AOV trend** (daily) — average order value fluctuations
4. **Sales by Order Segmentation** — New vs Returning vs VIP revenue *at the time of each order*
5. **Orders by Order Segmentation** — Volume distribution across segments *at the time of each order*
6. **Sales by Customer Profile** — Revenue *by customer's current segment*
7. **Orders by Customer Profile** — Volume *by customer's current segment*
8. **Segment performance table** — Segment | Orders | Net Sales | Avg Order Value | Avg Product Count Per Order

### Product Performance (from `mart_order_lines_looker_studio`)

9. **Top Products by Revenue** — Table: `product_id` | Revenue | Units | Orders
10. **Top Products by Units Sold** — Table: `product_id` | Units | Revenue | Orders
11. **Revenue by Product Line** — Bar chart: product line vs revenue
12. **Units Distribution** — Histogram of units per product across all order lines

### Top 10 Products

**By Revenue:**

| Product ID | Revenue | Units | Orders | Customers |
|---|---|---|---|---|
| 6197 | $3,993.06 | 316 | 66 | 20 |
| 26651 | $3,652.45 | 399 | 70 | 27 |
| 80643 | $3,629.10 | 187 | 36 | 14 |
| 43944 | $3,280.86 | 272 | 68 | 28 |
| 45368 | $2,344.82 | 68 | 8 | 3 |
| 76567 | $2,271.31 | 78 | 23 | 4 |
| 43945 | $2,101.88 | 174 | 40 | 16 |
| 43943 | $1,791.99 | 145 | 39 | 26 |
| 26652 | $1,400.84 | 154 | 32 | 14 |
| 45943 | $1,343.67 | 59 | 18 | 7 |

**By Units Sold:**

| Product ID | Units | Revenue | Orders | Customers |
|---|---|---|---|---|
| 26651 | 399 | $3,652.45 | 70 | 27 |
| 6197 | 316 | $3,993.06 | 66 | 20 |
| 43944 | 272 | $3,280.86 | 68 | 28 |
| 85159 | 231 | $552.64 | 61 | 37 |
| 70403 | 200 | $161.83 | 19 | 5 |
| 80643 | 187 | $3,629.10 | 36 | 14 |
| 79612 | 186 | $280.74 | 44 | 17 |
| 71058 | 178 | $174.89 | 39 | 7 |
| 43945 | 174 | $2,101.88 | 40 | 16 |
| 79107 | 158 | $515.06 | 50 | 34 |

> Products 45368 and 76567 crack the top 5 by revenue despite low unit counts (68 and 78) — they're high-value items.

### Mart Grain Design

| Mart | Grain | Rows | Use Case |
|---|---|---|---|
| `mart_order_lines` | 1 row per order × product | 28,360 | Flexible slicing by order, customer, date, segment |
| `mart_product_summary` | 1 row per product | 9,196 | Pre-aggregated product-level metrics |

`mart_order_lines` preserves the full grain for ad-hoc analysis (e.g., "which products do VIP customers buy?"). `mart_product_summary` is pre-aggregated for product dashboards — same answer, faster query.

### Dashboard Insights (all data: Jul 2025 – Dec 2026)

- **Revenue concentration**: Q4 (Oct–Dec) accounts for 39.1% of annual revenue ($105,212 of $269,044), driven by November (605 orders, 15.8% of annual volume).
- **Inverse volume-margin relationship**: November has the highest order count but the lowest average products per order (10.91).
- **Basket size anomaly**: April has the highest average products per order at 15.10, indicating unusually large baskets. The dataset doesn't have order-type information, so we can't confirm wholesale or bulk purchasing.
- **Acquisition vs retention**: 47.7% of all orders come from first-time buyers (New), but 52.3% come from Returning + VIP customers.
- **VIP leverage**: 21.7% of orders from VIPs, but they drive 29.0% of annual revenue.

### Revenue Contribution (all data: Jul 2025 – Dec 2026)

**Monthly breakdown:**

| Month | Revenue | % of Annual | Orders | % of Orders |
|---|---|---|---|---|
| Jan | $16,520 | 6.1% | 232 | 6.3% |
| Feb | $13,550 | 5.0% | 176 | 4.8% |
| Mar | $13,877 | 5.2% | 203 | 5.5% |
| Apr | $14,474 | 5.4% | 188 | 5.1% |
| May | $13,376 | 5.0% | 172 | 4.7% |
| Jun | $14,059 | 5.2% | 169 | 4.6% |
| Jul | $25,107 | 9.3% | 326 | 8.9% |
| Aug | $24,379 | 9.1% | 321 | 8.8% |
| Sep | $28,490 | 10.6% | 383 | 10.5% |
| Oct | $29,240 | 10.9% | 415 | 11.3% |
| Nov | $42,603 | 15.8% | 605 | 16.5% |
| Dec | $33,369 | 12.4% | 471 | 12.9% |

**Quarterly summary:**

| Quarter | Revenue | % of Annual | Orders | % of Orders |
|---|---|---|---|---|
| Q1 (Jan–Mar) | $43,947 | 16.3% | 611 | 16.7% |
| Q2 (Apr–Jun) | $41,909 | 15.6% | 529 | 14.4% |
| Q3 (Jul–Sep) | $77,976 | 29.0% | 1,030 | 28.1% |
| Q4 (Oct–Dec) | $105,212 | 39.1% | 1,491 | 40.7% |

### Diagnostic Logic

The three trend charts (Net Sales → Orders → AOV) work together to diagnose revenue changes:

```text
Revenue change observed
    ↓
Order volume change?
    ↓              ↓
    Yes            No
    ↓              ↓
More/fewer      Same volume
orders?         but different
    ↓           AOV?
    ↓              ↓
Investigate   Investigate
volume driver  pricing/basket
```

### Filters

- **Date** — Filter by order date range
- **Order Segmentation** — New / Returning / VIP at time of order
- **Customer Profile** — Customer's current segment (stable across all orders)
- **has_complete_12_month_history** — Filter to orders with complete lookback window

### Bonus: Sales Forecast (BigQuery ML + Looker Studio)

A BigQuery ML `ARIMA_PLUS` model (`sales_forecast`) trained on daily net sales from `mart_orders`. A date spine fills zero-sales days via `COALESCE`. Confidence bands floored at zero via `GREATEST(..., 0)`.

**Training details**: ~188 non-zero days over ~540 calendar days (Jul 2025 – Dec 2026). `auto_arima = true` lets the model select the best ARIMA order.

**TVFs created** (by `ingestion/create_forecast_model.py`):
- `v_sales_forecast()` — 30-day forecast horizon
- `v_sales_forecast_all()` — 7, 14, 30-day horizons with `horizon` column for parameterized Looker Studio queries

**Looker Studio setup**:

1. Add BigQuery data source → **Custom Query** → project `thtask`
2. Query: `SELECT * FROM v_sales_forecast_all() WHERE series_type = 'Actual' OR (series_type = 'Forecast' AND horizon = @forecast_horizon)`
3. Create parameter: `forecast_horizon` (Number, default `30`, list: `7`, `14`, `30`)
4. Time Series Chart: dimension = `date`, metrics = `daily_net_sales` + `forecast_value`, breakdown = `series_type`

---

## Data Quality Tests

### Generic Tests (YAML)

- `not_null` and `unique` on `order_id` in all models
- `not_null` on `customer_id`, `order_date`
- `accepted_values` on `order_segmentation` and `customer_profile` (New, Returning, VIP)
- `relationships` on `stg_sales.order_id` → `stg_orders.order_id` (severity: warn, catches orphan record 5361303)

### Production Tests

1. **`assert_orders_have_positive_product_qty`**: Fails if any order has `qty_product <= 0` or null.
2. **`assert_no_invalid_segments`**: Fails if any order has an unrecognized or null segment.
3. **`assert_order_sales_match`**: Fails if order-level `net_sales` and product-line `sum(line_net_sales)` differ by more than 0.01.
4. **`assert_segmentation_reconciliation`**: Fails if the dbt-computed `order_segmentation` does not match the LookML-derived rule.

### Challenge Regression Tests

1. **`assert_2026_order_count`**: Compares mart_orders 2026 count against stg_orders (no hardcoded number).
2. **`assert_2026_segmented_order_count`**: Validates 2026 segmented count matches.
3. **`assert_monthly_2026_orders_reconcile`**: Compares monthly totals between mart and source (no hardcoded numbers).
4. **`assert_order_grain`**: Validates one row per order.

### Test Results

All **62 data tests** — **61 PASS**, **1 WARN** (orphan order_id 5361303 at staging layer), **0 ERROR**.

---

## Key Data Insights

### Monthly Patterns (2026, `exercise_6_orders_segmented`)

- **November spike**: 389 orders — 2.33x the lowest month (August: 167). Likely seasonal or promotional activity, but we don't have promotion data to confirm.
- **Q4 dominance**: Oct–Dec account for 861 orders (33.5% of 2026 annual volume).
- **Inverse relationship in November**: Order volume peaks, but average products per order drops to 10.48 (lowest of any month).
- **April basket-size peak**: 15.10 avg products/order — highest of any month. Could indicate bulk or wholesale purchasing.

### Segmentation Analysis (2026, `exercise_6_orders_segmented`)

- **New customers dominate**: 42.2% of 2026 orders come from first-time buyers (1,087 orders).
- **Healthy retention**: 57.8% of orders come from Returning (30.9%) + VIP (26.9%) customers.
- **VIP concentration**: 26.9% of orders from VIPs (692 orders) suggests a loyal core.
- **Growth opportunity**: Converting 1,087 New customers into Returning is the highest-leverage retention play.

---

## Results Summary

| Check | Result |
|---|---|
| Source orders | 3,661 |
| 2025 orders | 1,088 |
| 2026 orders | 2,573 |
| Source sales rows | 28,361 |
| Distinct sales orders | 3,662 (1 orphan: 5361303) |
| Revenue reconciliation | Orders net_sales = Sales SUM(line_net_sales) within 0.01 (0 mismatches) |
| Order grain | 1 row/order in `mart_orders` |
| Product summary grain | Aggregated to order grain via `int_order_product_summary` |
| Segmentation | New / Returning / VIP (rolling 12-month, thresholds as dbt vars) |
| dbt tests | 61 PASS, 1 WARN (orphan FK at staging), 0 ERROR |
| LookML | Model + 2 Views + 2 Explores implemented |
| Dashboard | Looker Studio live + PDF export |
| Forecast | BigQuery ML ARIMA_PLUS + date spine + multi-horizon TVF |

---

## Documentation

| Document | Contents |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Full architecture with data lineage and design decisions |
| [`docs/DATA_QUALITY.md`](docs/DATA_QUALITY.md) | Data quality findings with quantified impact |
| [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md) | Limitations, their impact, and mitigations |
| [`docs/PRODUCTIONIZATION.md`](docs/PRODUCTIONIZATION.md) | Production readiness roadmap |
| [`ingestion/README.md`](ingestion/README.md) | Data ingestion pipeline docs |

---

## GCP Project

| Resource | Value |
|---|---|
| Project | `thtask` |
| Raw dataset | `recruitment_raw` |
| Analytics dataset | `recruitment_analytics` |
| Location | EU |
| dbt profile | `astrafy_bi` (target: `dev`) |
