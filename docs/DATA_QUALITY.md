# Data Quality Report

## Summary

| Check | Result | Details |
|---|---|---|
| Total orders | 3,661 | July 2025 – December 2026 |
| Total sales lines | 28,361 | One row per order × product |
| Total units sold | 47,729 | Sum of qty across all sales lines |
| Raw revenue | CHF 269,091.14 | Source-of-truth sum |
| Mart revenue | CHF 269,044.05 | After orphan exclusion (CHF 47.09 excluded) |
| Orphan sales lines | 1 | order_id 5361303 exists in sales but not orders |
| Same-day orders | 63 customer/date groups (47 distinct customers), 129 affected rows | Multiple orders on the same date by the same customer |
| Unique customers | 1,716 | Distinct customer_id values |
| Unique products | 9,196 | Distinct product_ids across all sales |
| DBT tests | 64 data tests | 62 PASS, 2 WARN (orphan FK at staging: relationship + sales→order header), 0 ERROR |

## Detailed Findings

### 1. Orphan Sales Record (order_id 5361303)

**What**: One order_id exists in `stg_sales` with no matching record in `stg_orders`.

**Quantified impact**:
- Excluded from `mart_orders`: 1 row, CHF 47.09 revenue, 1 product unit
- Excluded from `mart_order_lines`: 1 row, CHF 47.09 revenue, 1 product unit
- Excluded from `exercise_4_orders_with_qty`: 1 row, 1 product unit
- Excluded from `exercise_6_orders_segmented`: 1 row
- All downstream marts: 1,716 unique customers (unchanged if orphan included — customer 1382673 already has 5 orders in `stg_orders`)
- Revenue difference: CHF 269,091.14 (raw) - CHF 269,044.05 (mart) = CHF 47.09
- Units consistent across marts: `mart_orders` and `mart_order_lines` both report 47,728 units

**Test**: Caught by a `relationships` test in `staging.yml` with `severity: warn`.

**Mitigation**: This is a data quality issue in the source Excel. No action needed for the exercise.

### 2. Same-Day Order Ambiguity

**What**: 63 customer/date groups (47 distinct customers) placed multiple orders on the same calendar date. No timestamps are available.

**Quantified impact**:
- 129 order rows are part of same-day pairs/groups
- These orders cannot see each other in the 12-month lookback window
- Segmentation may misclassify: a customer's second same-day order is treated as if their first same-day order doesn't exist yet
- Edge case only: affects <4% of all orders

**Mitigation**: The lookback SQL uses `WHERE history.order_date < current_order.order_date` (strictly before). Same-day orders cannot be deterministically sequenced because timestamps are unavailable. They are therefore excluded from each other's lookback history.

### 3. Partitioning Not Applied

**What**: Partitioning not needed at current scale (~3.6k orders, ~28k order lines). Clustering on `customer_id` and `order_segmentation` provides adequate query performance. Full table scans complete in <3 seconds.

### 4. Forecasting Data Gaps

**What**: The raw data contains only days with at least one order. Days with zero sales are absent.

**Quantified impact**: The daily series runs 2025-07-09 → 2026-12-31 (541 calendar days). 539 days have orders; only 2 days (2026-05-19 and 2026-05-20) have no orders. These 2 days are absent from the raw data rather than present as `0`.

**Mitigation**: `date_spine` approach implemented in the forecast script to COALESCE the 2 missing days to zero.

### 5. Complete History Window

**What**: The 12-month lookback window extends before the dataset start (2025-07-09) for orders placed before 2026-07-09.

**Quantified impact**: Orders before 2026-07-09 have an incomplete prior-history window. This affects "New" classification — a customer could appear "New" simply because their prior orders fall outside the available data.

**Mitigation**: `has_complete_12_month_history` boolean added to `mart_orders`. Dashboard should filter on this field for accurate segmentation analysis. See dashboard warning note.

## Production Recommendations

1. **Add timestamps** to order data to resolve same-day ambiguity
2. **Investigate orphan** order_id 5361303 upstream — may indicate a data pipeline issue
3. **Add source freshness checks** to detect missing or stale Excel loads
4. **Date spine in mart** for forecasting and reporting (days with zero sales should be visible)
