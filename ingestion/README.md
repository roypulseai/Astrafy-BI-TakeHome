# XLSX to BigQuery Ingestion

Scripts for loading raw data and training the forecast model.

## Prerequisites

1. Python 3.9+
2. Google Cloud SDK authenticated (`gcloud auth application-default login`)
3. BigQuery API enabled in your GCP project

## Setup

```bash
pip install pandas google-cloud-bigquery google-cloud-bigquery-storage openpyxl
```

## Step 1: Load raw data

Place the two XLSX files in the project root (`TH_DBT_BQ_LookML/`):

```text
TH_DBT_BQ_LookML/
├── orders_recrutement.xlsx
├── sales_recrutement.xlsx
└── ingestion/
    └── load_to_bigquery.py
```

Run:

```bash
python ingestion/load_to_bigquery.py --project YOUR_PROJECT_ID
```

## Step 2: Build dbt models

```bash
dbt build
dbt test
dbt docs generate
```

This creates all staging, intermediate, and mart models, including:
- `mart_orders` (canonical order-level analytical table)
- `mart_orders_looker_studio` (BI presentation view for Looker Studio)
- `exercise_4_orders_with_qty` and `exercise_6_orders_segmented` (exercise deliverables)

## Step 3 (Optional): Train forecast model

```bash
python ingestion/create_forecast_model.py \
  --project YOUR_PROJECT_ID \
  --dataset recruitment_analytics \
  --location EU
```

This trains the ARIMA_PLUS model and creates forecast TVFs.
The Looker Studio view is created by dbt (Step 2), not by this script.

## What it does

### load_to_bigquery.py

1. Creates the `recruitment_raw` dataset if it does not exist (location: EU).
2. Loads `orders_recrutement.xlsx` → `recruitment_raw.orders_recrutement`.
3. Loads `sales_recrutement.xlsx` → `recruitment_raw.sales_recrutement`.
4. Validates required columns and reports nulls/row counts.

### create_forecast_model.py

1. Trains `ARIMA_PLUS` model on daily net sales from `mart_orders`.
2. Creates `v_sales_forecast()` (30-day horizon TVF).
3. Creates `v_sales_forecast_all()` (multi-horizon TVF with horizon column).

## Notes

- The scripts use `WRITE_TRUNCATE`, so re-running replaces existing data.
- Do not commit the XLSX files to a public repository.
- `mart_orders_looker_studio` is a dbt view — Looker Studio should point at this, not at `mart_orders`.
