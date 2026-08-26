"""
XLSX to BigQuery ingestion script for the Astrafy BI Engineer take-home challenge.

Usage:
    1. Place orders_recrutement.xlsx and sales_recrutement.xlsx in the TH_DBT_BQ_LookML/ folder.
    2. Install dependencies: pip install pandas google-cloud-bigquery google-cloud-bigquery-storage openpyxl
    3. Authenticate: gcloud auth application-default login
    4. Run: python ingestion/load_to_bigquery.py --project YOUR_PROJECT_ID

The script creates two BigQuery tables in the recruitment_raw dataset:
    - orders_recrutement
    - sales_recrutement
"""

import argparse
import os
import sys

import pandas as pd
from google.cloud import bigquery


def load_orders(client, project_id, file_path):
    """Load orders_recrutement.xlsx into BigQuery."""
    print(f"Loading orders from {file_path}...")

    df = pd.read_excel(file_path, engine="openpyxl")

    print(f"  Rows: {len(df)}")
    print(f"  Columns: {list(df.columns)}")
    print(f"  Date range: {df['date_date'].min()} to {df['date_date'].max()}")

    required_columns = {"orders_id", "customers_id", "date_date", "net_sales"}
    missing = required_columns - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns in orders: {missing}")

    null_counts = df[list(required_columns)].isnull().sum()
    if null_counts.any():
        print(f"  WARNING - Null values found:\n{null_counts[null_counts > 0]}")

    table_id = f"{project_id}.recruitment_raw.orders_recrutement"

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",
        autodetect=True,
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()

    table = client.get_table(table_id)
    print(f"  Loaded {table.num_rows} rows into {table_id}\n")


def load_sales(client, project_id, file_path):
    """Load sales_recrutement.xlsx into BigQuery."""
    print(f"Loading sales from {file_path}...")

    df = pd.read_excel(file_path, engine="openpyxl")

    print(f"  Rows: {len(df)}")
    print(f"  Columns: {list(df.columns)}")

    required_columns = {"order_id", "products_id", "qty"}
    missing = required_columns - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns in sales: {missing}")

    table_id = f"{project_id}.recruitment_raw.sales_recrutement"

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",
        autodetect=True,
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()

    table = client.get_table(table_id)
    print(f"  Loaded {table.num_rows} rows into {table_id}\n")


def main():
    parser = argparse.ArgumentParser(description="Load XLSX files into BigQuery")
    parser.add_argument("--project", required=True, help="Google Cloud project ID")
    args = parser.parse_args()

    project_id = args.project

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    orders_path = os.path.join(base_dir, "orders_recrutement.xlsx")
    sales_path = os.path.join(base_dir, "sales_recrutement.xlsx")

    if not os.path.exists(orders_path):
        sys.exit(f"ERROR: File not found: {orders_path}")
    if not os.path.exists(sales_path):
        sys.exit(f"ERROR: File not found: {sales_path}")

    client = bigquery.Client(project=project_id)

    dataset_id = f"{project_id}.recruitment_raw"
    try:
        client.get_dataset(dataset_id)
        print(f"Dataset {dataset_id} already exists.")
    except Exception:
        print(f"Creating dataset {dataset_id}...")
        dataset = bigquery.Dataset(dataset_id)
        dataset.location = "EU"
        client.create_dataset(dataset, exists_ok=True)
        print(f"Dataset {dataset_id} created.\n")

    analytics_dataset_id = f"{project_id}.recruitment_analytics"
    try:
        client.get_dataset(analytics_dataset_id)
        print(f"Dataset {analytics_dataset_id} already exists.\n")
    except Exception:
        print(f"Creating dataset {analytics_dataset_id}...")
        dataset = bigquery.Dataset(analytics_dataset_id)
        dataset.location = "EU"
        client.create_dataset(dataset, exists_ok=True)
        print(f"Dataset {analytics_dataset_id} created.\n")

    load_orders(client, project_id, orders_path)
    load_sales(client, project_id, sales_path)

    print("Ingestion complete.")


if __name__ == "__main__":
    main()
