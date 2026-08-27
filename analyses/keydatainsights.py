import os
from google.cloud import bigquery

os.environ["GOOGLE_CLOUD_PROJECT"] = "thtask"
client = bigquery.Client()

print("=" * 60)
print("KEY DATA INSIGHTS VERIFICATION")
print("=" * 60)

# 1. Monthly Patterns (2026)
print("\n--- Monthly Patterns (2026) ---")
q_monthly = """
SELECT
    FORMAT_TIMESTAMP('%b', order_date) AS month_name,
    EXTRACT(MONTH FROM order_date) AS month_num,
    COUNT(*) AS orders,
    ROUND(SUM(qty_product), 2) AS total_qty,
    ROUND(SAFE_DIVIDE(SUM(qty_product), COUNT(*)), 2) AS avg_products_per_order,
    ROUND(SUM(net_sales), 2) AS total_revenue
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'
GROUP BY 1, 2
ORDER BY 2
"""
for row in client.query(q_monthly).result():
    print(f"  {row.month_name:4s} {row.month_num:2d}: {row.orders:4d} orders, {row.total_qty:7.0f} qty, avg {row.avg_products_per_order:5.2f}, rev CHF {row.total_revenue:,.2f}")

# Q4 calculation
q_q4 = """
SELECT COUNT(*) AS q4_orders,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `thtask.recruitment_analytics.mart_orders`
                                   WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'), 1) AS pct
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_date >= '2026-10-01' AND order_date < '2027-01-01'
"""
for row in client.query(q_q4).result():
    print(f"\n  Q4 (Oct-Dec): {row.q4_orders} orders, {row.pct}% of annual")

# November spike ratio
q_nov = """
WITH monthly AS (
    SELECT EXTRACT(MONTH FROM order_date) AS m, COUNT(*) AS cnt
    FROM `thtask.recruitment_analytics.mart_orders`
    WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'
    GROUP BY 1
),
ranked AS (
    SELECT m, cnt,
           ROW_NUMBER() OVER (ORDER BY cnt DESC) AS rn_max,
           ROW_NUMBER() OVER (ORDER BY cnt ASC) AS rn_min
    FROM monthly
)
SELECT
    (SELECT cnt FROM ranked WHERE rn_max = 1) AS max_orders,
    (SELECT cnt FROM ranked WHERE rn_min = 1) AS min_orders,
    (SELECT m FROM ranked WHERE rn_max = 1) AS max_month,
    (SELECT m FROM ranked WHERE rn_min = 1) AS min_month
"""
for row in client.query(q_nov).result():
    max_m = int(row.max_month)
    min_m = int(row.min_month)
    months = {1:'Jan',2:'Feb',3:'Mar',4:'Apr',5:'May',6:'Jun',7:'Jul',8:'Aug',9:'Sep',10:'Oct',11:'Nov',12:'Dec'}
    ratio = round(row.max_orders / row.min_orders, 1)
    print(f"\n  November spike: {row.max_orders} vs {row.min_orders} ({months[max_m]}: {ratio}x lowest = {months[min_m]})")

# 2. Segmentation Analysis (2026)
print("\n--- Segmentation Analysis (2026) ---")
q_seg = """
SELECT
    order_segmentation,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct,
    ROUND(SUM(net_sales), 2) AS revenue
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'
GROUP BY 1
ORDER BY 2 DESC
"""
for row in client.query(q_seg).result():
    print(f"  {row.order_segmentation:10s}: {row.orders:4d} orders, {row.pct:5.1f}%, rev CHF {row.revenue:,.2f}")

# Returning + VIP combined
q_ret_vip = """
SELECT COUNT(*) AS orders,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `thtask.recruitment_analytics.mart_orders`
                                   WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'), 1) AS pct
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_segmentation IN ('Returning', 'VIP')
  AND order_date >= '2026-01-01' AND order_date < '2027-01-01'
"""
for row in client.query(q_ret_vip).result():
    print(f"\n  Returning + VIP combined: {row.orders} orders, {row.pct}%")

# 3. Overall stats
print("\n--- Overall Stats ---")
q_overall = """
SELECT
    COUNT(*) AS total_orders,
    COUNTIF(order_date >= '2026-01-01' AND order_date < '2027-01-01') AS orders_2026,
    COUNTIF(order_date >= '2025-01-01' AND order_date < '2026-01-01') AS orders_2025,
    ROUND(SUM(net_sales), 2) AS total_revenue,
    ROUND(SAFE_DIVIDE(SUM(net_sales), COUNT(*)), 2) AS aov,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM `thtask.recruitment_analytics.mart_orders`
"""
for row in client.query(q_overall).result():
    print(f"  Total orders: {row.total_orders}")
    print(f"  2025 orders: {row.orders_2025}")
    print(f"  2026 orders: {row.orders_2026}")
    print(f"  Total revenue: CHF {row.total_revenue:,.2f}")
    print(f"  AOV: CHF {row.aov:,.2f}")
    print(f"  Unique customers: {row.unique_customers}")

# 4. Orphan check
print("\n--- Orphan Sales ---")
q_orphan = """
SELECT COUNT(*) AS orphan_lines
FROM `thtask.recruitment_analytics.stg_sales` s
LEFT JOIN `thtask.recruitment_analytics.stg_orders` o ON s.order_id = o.order_id
WHERE o.order_id IS NULL
"""
for row in client.query(q_orphan).result():
    print(f"  Orphan sales lines: {row.orphan_lines}")

# 5. Same-day collision
print("\n--- Same-Day Collision ---")
q_sameday = """
WITH multi AS (
    SELECT customer_id, order_date, COUNT(*) AS cnt
    FROM `thtask.recruitment_analytics.mart_orders`
    GROUP BY customer_id, order_date
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS affected_customers,
    SUM(cnt) AS affected_rows
FROM multi
"""
for row in client.query(q_sameday).result():
    print(f"  Affected customers: {row.affected_customers}")
    print(f"  Affected order rows: {row.affected_rows}")

# 6. Data completeness
print("\n--- Data Completeness ---")
q_hist = """
SELECT
    SUM(CASE WHEN has_complete_12_month_history THEN 1 ELSE 0 END) AS full_history,
    SUM(CASE WHEN NOT has_complete_12_month_history THEN 1 ELSE 0 END) AS partial_history,
    COUNT(*) AS total
FROM `thtask.recruitment_analytics.mart_orders`
"""
for row in client.query(q_hist).result():
    print(f"  Full 12mo history: {row.full_history}")
    print(f"  Partial history: {row.partial_history}")
    print(f"  Total: {row.total}")

# 7. Revenue reconciliation
print("\n--- Revenue Reconciliation ---")
q_rev = """
WITH order_rev AS (
    SELECT SUM(net_sales) AS order_total FROM `thtask.recruitment_analytics.mart_orders`
),
sales_rev AS (
    SELECT SUM(net_sales) AS sales_total FROM `thtask.recruitment_analytics.mart_order_lines`
)
SELECT order_total, sales_total, ABS(order_total - sales_total) AS diff
FROM order_rev, sales_rev
"""
for row in client.query(q_rev).result():
    print(f"  Order total: CHF {row.order_total:,.2f}")
    print(f"  Sales total: CHF {row.sales_total:,.2f}")
    print(f"  Difference: CHF {row.diff:,.2f}")

# 8. Monthly 2026 for exercise answers verification
print("\n--- Exercise 2 Verification (Monthly 2026) ---")
q_ex2 = """
SELECT
    EXTRACT(MONTH FROM order_date) AS m,
    COUNT(*) AS cnt
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'
GROUP BY 1 ORDER BY 1
"""
month_names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
for row in client.query(q_ex2).result():
    print(f"  {month_names[row.m-1]:3s}: {row.cnt}")

# 9. Exercise 3 verification (avg products per order by month)
print("\n--- Exercise 3 Verification (Avg Products/Order by Month 2026) ---")
q_ex3 = """
SELECT
    EXTRACT(MONTH FROM order_date) AS m,
    ROUND(AVG(qty_product), 2) AS avg_qty
FROM `thtask.recruitment_analytics.mart_orders`
WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'
GROUP BY 1 ORDER BY 1
"""
for row in client.query(q_ex3).result():
    print(f"  {month_names[row.m-1]:3s}: {row.avg_qty}")

print("\n" + "=" * 60)
print("VERIFICATION COMPLETE")
print("=" * 60)
