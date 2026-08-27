# Exercise Answers

Answers to the coding-challenge exercises, computed from the pipeline that lives in this repository (`mart_orders` → filtered marts) and verified directly against the supplied source files (`orders_recrutement`, `sales_recrutement`).

All revenue is in **CHF**. The supplied data covers **2025-07-09 → 2026-12-31** (the challenge brief mentions 2022–2023, but the actual files contain 2025–2026 — the files are treated as the source of truth; see the main README "Data Source Truth Check").

---

## Exercice 1 — Number of orders in the year 2026

**2,573 orders**

```sql
select count(*) as nb_orders_2026
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date <  date('2027-01-01');
```

---

## Exercice 2 — Number of orders per month in the year 2026

| Month | Orders |
|---|---|
| Jan | 232 |
| Feb | 176 |
| Mar | 203 |
| Apr | 188 |
| May | 172 |
| Jun | 169 |
| Jul | 193 |
| Aug | 167 |
| Sep | 212 |
| Oct | 223 |
| Nov | 389 |
| Dec | 249 |
| **Total** | **2,573** |

```sql
select
    date_trunc(order_date, month) as order_month,
    count(*) as nb_orders
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date <  date('2027-01-01')
group by 1
order by 1;
```

---

## Exercice 3 — Average number of products per order, per month (2026)

| Month | Avg products/order |
|---|---|
| Jan | 12.57 |
| Feb | 12.62 |
| Mar | 13.07 |
| Apr | 15.10 |
| May | 14.63 |
| Jun | 14.18 |
| Jul | 13.75 |
| Aug | 14.46 |
| Sep | 13.67 |
| Oct | 13.03 |
| Nov | 10.48 |
| Dec | 11.37 |

```sql
select
    date_trunc(order_date, month) as order_month,
    round(avg(qty_product), 2) as avg_qty_products_per_order
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date <  date('2027-01-01')
group by 1
order by 1;
```

> `qty_product` is the total quantity of products in an order (sum of `qty` across the order's product lines), so the monthly average is the average basket size for that month.

---

## Exercice 4 — Table (1 line per order) for all orders in 2025 and 2026, with `qty_product`

Delivered by the view **`exercise_4_orders_with_qty`** (1 row per order, 2025–2026).

**3,661 rows** (2025: 1,088; 2026: 2,573).

Columns:

- `order_id`
- `customer_id`
- `order_date`
- `net_sales`
- `qty_product` — quantity of products in the order

```sql
-- models/marts/exercise_4_orders_with_qty.sql
select
    order_id,
    customer_id,
    order_date,
    net_sales,
    qty_product
from {{ ref('mart_orders') }}
where order_date >= date('2025-01-01')
  and order_date <  date('2027-01-01');
```

> One orphan sales record (`order_id 5361303`, no matching order header) is excluded, so order-level revenue reconciles with the underlying sales lines within CHF 0.01.

---

## Exercice 5 — Order segmentation (2026)

Each order is assigned a segment based on the customer's order history in the **preceding 12 months** (excluding the current order):

- **New**: the customer placed **0** prior orders in the past 12 months (it's the 1st order in that window)
- **Returning**: the customer placed **1–3** prior orders in the past 12 months (2nd–4th order)
- **VIP**: the customer placed **4+** prior orders in the past 12 months (5th order or more)

Segmentation is **point-in-time at order time** — the same customer can move between segments as they place more orders.

| Segment | Orders (2026) | % of 2026 orders |
|---|---|---|
| New | 1,087 | 42.2% |
| Returning | 794 | 30.9% |
| VIP | 692 | 26.9% |
| **Total** | **2,573** | **100%** |

```sql
-- macro: macros/get_order_segment.sql
{% macro get_order_segment(prior_order_count) %}
case
    when {{ prior_order_count }} <= {{ var('new_customer_max_prior_orders') }} then 'New'
    when {{ prior_order_count }} between {{ var('returning_min_prior_orders') }} and {{ var('returning_max_prior_orders') }} then 'Returning'
    when {{ prior_order_count }} >= {{ var('vip_min_prior_orders') }} then 'VIP'
    else 'Unknown'
end
{% endmacro %}
```

> The lookback count is computed in `int_order_customer_history` using a rolling 12-month window (`order_date < current_order.order_date`, strictly earlier dates). Same-day orders from the same customer cannot be sequenced because no timestamps are present, so they are excluded from each other's prior history. Thresholds are config-driven (`dbt_project.yml` vars), not hardcoded.

---

## Exercice 6 — Table (1 line per order) for 2026 only, with `order_segmentation`

Delivered by the view **`exercise_6_orders_segmented`** (1 row per order, 2026 only).

**2,573 rows**.

Columns:

- `order_id`
- `customer_id`
- `order_date`
- `net_sales`
- `qty_product`
- `order_segmentation` — New / Returning / VIP (at the time of that order)

```sql
-- models/marts/exercise_6_orders_segmented.sql
select
    order_id,
    customer_id,
    order_date,
    net_sales,
    qty_product,
    order_segmentation
from {{ ref('mart_orders') }}
where order_date >= date('2026-01-01')
  and order_date <  date('2027-01-01');
```

---

## Supporting tests

These regression tests guard the exercise answers (no hardcoded numbers — they compare marts against the staging/source layer dynamically):

- `tests/challenge_regression/assert_2026_order_count.sql` — 2026 order count in `mart_orders` == `stg_orders`
- `tests/challenge_regression/assert_monthly_2026_orders_reconcile.sql` — monthly 2026 totals match by month
- `tests/challenge_regression/assert_order_grain.sql` — no duplicate `order_id` in `mart_orders` (one row per order)
- `tests/challenge_regression/assert_2026_segmented_order_count.sql` — segmented 2026 count == `stg_orders` count
