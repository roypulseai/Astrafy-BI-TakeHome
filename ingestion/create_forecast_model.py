"""
Train a BigQuery ML ARIMA_PLUS forecast model on daily net sales
and create table-valued functions for Looker Studio integration.

Usage:
    python ingestion/create_forecast_model.py \
        --project YOUR_PROJECT_ID \
        --dataset recruitment_analytics \
        --location EU
"""
import argparse
import os
from google.cloud import bigquery


def main():
    parser = argparse.ArgumentParser(
        description="Train ARIMA_PLUS forecast model and create forecast TVFs."
    )
    parser.add_argument("--project", required=True, help="GCP project ID.")
    parser.add_argument("--dataset", default="recruitment_analytics", help="BigQuery dataset name.")
    parser.add_argument("--location", default="EU", help="BigQuery dataset location.")
    args = parser.parse_args()

    project = args.project
    dataset = args.dataset
    table_ref = f"`{project}.{dataset}`"

    os.environ["GOOGLE_CLOUD_PROJECT"] = project
    client = bigquery.Client(project=project, location=args.location)

    # Step 1: Train ARIMA_PLUS model on daily net sales
    # Uses a date spine with COALESCE to ensure zero-fill for days without orders.
    print("Step 1: Training ARIMA_PLUS forecast model...")
    sql_model = f"""
    CREATE OR REPLACE MODEL {table_ref}.sales_forecast
    OPTIONS (
        model_type = 'ARIMA_PLUS',
        time_series_timestamp_col = 'order_date',
        time_series_data_col = 'daily_net_sales',
        auto_arima = true
    )
    AS
    WITH date_spine AS (
        SELECT order_date
        FROM UNNEST(GENERATE_DATE_ARRAY(
            (SELECT MIN(order_date) FROM {table_ref}.mart_orders),
            (SELECT MAX(order_date) FROM {table_ref}.mart_orders)
        )) AS order_date
    ),
    daily_sales AS (
        SELECT
            order_date,
            COALESCE(SUM(net_sales), 0) AS daily_net_sales
        FROM date_spine
        LEFT JOIN {table_ref}.mart_orders USING (order_date)
        GROUP BY order_date
    )
    SELECT order_date, daily_net_sales FROM daily_sales
    """
    client.query(sql_model).result()
    print("Model trained!")

    # Step 2: Create TVFs (drop old ones first)
    print("\nStep 2: Creating TVFs...")
    client.query(f"DROP VIEW IF EXISTS {table_ref}.v_sales_forecast").result()
    client.query(f"DROP VIEW IF EXISTS {table_ref}.v_sales_forecast_all").result()
    print("Old TVFs dropped.")

    # Create a fixed-horizon TVF (30 days) for general use
    print("Creating TVF v_sales_forecast (30-day default)...")
    sql_tvf = f"""
    CREATE OR REPLACE TABLE FUNCTION {table_ref}.v_sales_forecast()
    AS (
        WITH actuals AS (
            SELECT
                order_date AS date,
                SUM(net_sales) AS daily_net_sales,
                CAST(NULL AS FLOAT64) AS forecast_value,
                CAST(NULL AS FLOAT64) AS confidence_lower,
                CAST(NULL AS FLOAT64) AS confidence_upper,
                'Actual' AS series_type
            FROM {table_ref}.mart_orders
            GROUP BY order_date
        ),
        forecast AS (
            SELECT
                DATE(forecast_timestamp) AS date,
                CAST(NULL AS FLOAT64) AS daily_net_sales,
                forecast_value,
                GREATEST(confidence_interval_lower_bound, 0) AS confidence_lower,
                confidence_interval_upper_bound AS confidence_upper,
                'Forecast' AS series_type
            FROM ML.FORECAST(
                MODEL {table_ref}.sales_forecast,
                STRUCT(30 AS horizon, 0.95 AS confidence_level)
            )
        )
        SELECT * FROM actuals
        UNION ALL
        SELECT * FROM forecast
    );
    """
    client.query(sql_tvf).result()
    print("TVF v_sales_forecast created!")

    # Create multi-horizon TVF for Looker Studio dynamic forecast
    print("\nCreating TVF v_sales_forecast_all (horizons 7, 14, 30)...")
    sql_tvf_all = f"""
    CREATE OR REPLACE TABLE FUNCTION {table_ref}.v_sales_forecast_all()
    AS (
        WITH actuals AS (
            SELECT
                order_date AS date,
                SUM(net_sales) AS daily_net_sales,
                CAST(NULL AS FLOAT64) AS forecast_value,
                CAST(NULL AS FLOAT64) AS confidence_lower,
                CAST(NULL AS FLOAT64) AS confidence_upper,
                'Actual' AS series_type,
                CAST(NULL AS INT64) AS horizon
            FROM {table_ref}.mart_orders
            GROUP BY order_date
        ),
        forecast_7 AS (
            SELECT DATE(forecast_timestamp) AS date,
                   CAST(NULL AS FLOAT64) AS daily_net_sales, forecast_value,
                   GREATEST(confidence_interval_lower_bound, 0) AS confidence_lower,
                   confidence_interval_upper_bound AS confidence_upper,
                   'Forecast' AS series_type, 7 AS horizon
            FROM ML.FORECAST(MODEL {table_ref}.sales_forecast,
                             STRUCT(7 AS horizon, 0.95 AS confidence_level))
        ),
        forecast_14 AS (
            SELECT DATE(forecast_timestamp) AS date,
                   CAST(NULL AS FLOAT64) AS daily_net_sales, forecast_value,
                   GREATEST(confidence_interval_lower_bound, 0) AS confidence_lower,
                   confidence_interval_upper_bound AS confidence_upper,
                   'Forecast' AS series_type, 14 AS horizon
            FROM ML.FORECAST(MODEL {table_ref}.sales_forecast,
                             STRUCT(14 AS horizon, 0.95 AS confidence_level))
        ),
        forecast_30 AS (
            SELECT DATE(forecast_timestamp) AS date,
                   CAST(NULL AS FLOAT64) AS daily_net_sales, forecast_value,
                   GREATEST(confidence_interval_lower_bound, 0) AS confidence_lower,
                   confidence_interval_upper_bound AS confidence_upper,
                   'Forecast' AS series_type, 30 AS horizon
            FROM ML.FORECAST(MODEL {table_ref}.sales_forecast,
                             STRUCT(30 AS horizon, 0.95 AS confidence_level))
        )
        SELECT * FROM actuals
        UNION ALL SELECT * FROM forecast_7
        UNION ALL SELECT * FROM forecast_14
        UNION ALL SELECT * FROM forecast_30
    );
    """
    client.query(sql_tvf_all).result()
    print("TVF v_sales_forecast_all created!")

    # Test both TVFs
    print("\n--- v_sales_forecast (30-day) ---")
    sql_test = f"""
    SELECT date, daily_net_sales, forecast_value, series_type
    FROM {table_ref}.v_sales_forecast()
    ORDER BY date DESC LIMIT 5
    """
    for row in client.query(sql_test):
        if row.series_type == "Actual":
            print(f"  {row.date}: Actual = ${row.daily_net_sales:.2f}")
        else:
            print(f"  {row.date}: Forecast = ${row.forecast_value:.2f}")

    print("\n--- v_sales_forecast_all (all horizons) ---")
    sql_test2 = f"""
    SELECT series_type, horizon, COUNT(*) AS row_count
    FROM {table_ref}.v_sales_forecast_all()
    GROUP BY series_type, horizon
    ORDER BY series_type, horizon
    """
    for row in client.query(sql_test2):
        print(f"  {row.series_type}: horizon={row.horizon}, rows={row.row_count}")

    print("\nDone!")


if __name__ == "__main__":
    main()
