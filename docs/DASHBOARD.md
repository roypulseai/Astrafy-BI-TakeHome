# Dashboard Details

KPI dictionary, charts, top-product tables, and revenue breakdowns for the Looker Studio dashboard. High-level design and LookML are in the [main README](../README.md).

---

## KPI Dictionary

| KPI | Definition | Grain | Source |
| --- | --- | --- | --- |
| Orders | Count of orders | Order | `SUM(order_count)` |
| Revenue | Net sales at order level | Order | `SUM(net_sales)` |
| Customers | Distinct customers (SHA256 hash) | Customer | `COUNT_DISTINCT(customer_ref)` |
| AOV | Revenue / Orders | Order | Calculated field |
| Products/order | Total product quantity / Orders | Order | `SUM(qty_product) / SUM(order_count)` |
| Order Segmentation | Rolling 12-month customer history at time of order | Order | `order_segmentation` dimension (New/Returning/VIP) |
| Customer Profile | Customer's current segment based on latest order | Order | `customer_profile` dimension (New/Returning/VIP) |

## KPI Tiles

| KPI | Looker Studio Formula | Validated Value |
| --- | --- | --- |
| Net Sales | `SUM(net_sales)` | CHF269,044.05 |
| Orders | `SUM(order_count)` | 3,661 |
| Average Order Value | `SUM(net_sales) / SUM(order_count)` | CHF73.49 |
| Products Sold | `SUM(qty_product)` | 47,728 |
| Avg Products per Order | `SUM(qty_product) / SUM(order_count)` | 13.04 |
| Unique Customers | `COUNT_DISTINCT(customer_ref)` | 1,716 |

> Products Sold is 47,728 (not 47,729) because the orphan order_id 5361303 with 1 unit is excluded from the mart.

## Charts

1. **Net Sales trend** (daily) — revenue patterns and anomalies
2. **Orders trend** (daily) — order volume changes
3. **AOV trend** (daily) — average order value fluctuations
4. **Sales by Order Segmentation** — New vs Returning vs VIP revenue *at the time of each order*
5. **Orders by Order Segmentation** — volume distribution across segments *at the time of each order*
6. **Sales by Customer Profile** — revenue *by customer's current segment*
7. **Orders by Customer Profile** — volume *by customer's current segment*
8. **Segment performance table** — Segment | Orders | Net Sales | Avg Order Value | Avg Product Count Per Order
9. **Top Products by Revenue** (from `mart_order_lines_looker_studio`) — table: `product_id` | Revenue | Units | Orders
10. **Top Products by Units Sold** — table: `product_id` | Units | Revenue | Orders
11. **Revenue by Product Line** — bar chart: product line vs revenue
12. **Units Distribution** — histogram of units per product across all order lines

### How to read the dashboard

The three trend charts (Net Sales → Orders → AOV) work together to diagnose revenue changes:

```
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

- **Date** — filter by order date range
- **Order Segmentation** — New / Returning / VIP at time of order
- **Customer Profile** — customer's current segment (stable across all orders)
- **has_complete_12_month_history** — filter to orders with complete lookback window

---

## Top 10 Products

**By Revenue:**

| Product ID | Revenue | Units | Orders | Customers |
| --- | --- | --- | --- | --- |
| 6197 | CHF3,993.06 | 316 | 66 | 20 |
| 26651 | CHF3,652.45 | 399 | 70 | 27 |
| 80643 | CHF3,629.10 | 187 | 36 | 14 |
| 43944 | CHF3,280.86 | 272 | 68 | 28 |
| 45368 | CHF2,344.82 | 68 | 8 | 3 |
| 76567 | CHF2,271.31 | 78 | 23 | 4 |
| 43945 | CHF2,101.88 | 174 | 40 | 16 |
| 43943 | CHF1,791.99 | 145 | 39 | 26 |
| 26652 | CHF1,400.84 | 154 | 32 | 14 |
| 45943 | CHF1,343.67 | 59 | 18 | 7 |

**By Units Sold:**

| Product ID | Units | Revenue | Orders | Customers |
| --- | --- | --- | --- | --- |
| 26651 | 399 | CHF3,652.45 | 70 | 27 |
| 6197 | 316 | CHF3,993.06 | 66 | 20 |
| 43944 | 272 | CHF3,280.86 | 68 | 28 |
| 85159 | 231 | CHF552.64 | 61 | 37 |
| 70403 | 200 | CHF161.83 | 19 | 5 |
| 80643 | 187 | CHF3,629.10 | 36 | 14 |
| 79612 | 186 | CHF280.74 | 44 | 17 |
| 71058 | 178 | CHF174.89 | 39 | 7 |
| 43945 | 174 | CHF2,101.88 | 40 | 16 |
| 79107 | 158 | CHF515.06 | 50 | 34 |

> Products 45368 and 76567 crack the top 5 by revenue despite low unit counts (68 and 78) — they're high-value items.

---

## Mart Grain Design

| Mart | Grain | Rows | Use Case |
| --- | --- | --- | --- |
| `mart_order_lines` | 1 row per order × product | 28,360 | Flexible slicing by order, customer, date, segment |
| `mart_product_summary` | 1 row per product | 9,196 | Pre-aggregated product-level metrics |

`mart_order_lines` preserves the full grain for ad-hoc analysis (e.g., "which products do VIP customers buy?"). `mart_product_summary` is pre-aggregated for product dashboards — same answer, faster query.

---

## Revenue Contribution (all data: Jul 2025 – Dec 2026)

The source data spans 18 months. Annual totals below are for the full period. Charts in Looker Studio filter by calendar year.

**2025 H2 (Jul – Dec):**

| Month | Revenue | % of Total | Orders | % of Orders |
| --- | --- | --- | --- | --- |
| Jul | CHF 9,093 | 3.4% | 133 | 3.6% |
| Aug | CHF 12,105 | 4.5% | 154 | 4.2% |
| Sep | CHF 12,896 | 4.8% | 171 | 4.7% |
| Oct | CHF 14,196 | 5.3% | 192 | 5.2% |
| Nov | CHF 16,521 | 6.1% | 216 | 5.9% |
| Dec | CHF 16,037 | 6.0% | 222 | 6.1% |
| **Subtotal** | **CHF 80,848** | **30.1%** | **1,088** | **29.7%** |

**2026 (Jan – Dec):**

| Month | Revenue | % of Total | Orders | % of Orders |
| --- | --- | --- | --- | --- |
| Jan | CHF 16,520 | 6.1% | 232 | 6.3% |
| Feb | CHF 13,550 | 5.0% | 176 | 4.8% |
| Mar | CHF 13,877 | 5.2% | 203 | 5.5% |
| Apr | CHF 14,474 | 5.4% | 188 | 5.1% |
| May | CHF 13,376 | 5.0% | 172 | 4.7% |
| Jun | CHF 14,059 | 5.2% | 169 | 4.6% |
| Jul | CHF 16,014 | 6.0% | 193 | 5.3% |
| Aug | CHF 12,274 | 4.6% | 167 | 4.6% |
| Sep | CHF 15,593 | 5.8% | 212 | 5.8% |
| Oct | CHF 15,044 | 5.6% | 223 | 6.1% |
| Nov | CHF 26,083 | 9.7% | 389 | 10.6% |
| Dec | CHF 17,332 | 6.4% | 249 | 6.8% |
| **Subtotal** | **CHF 188,196** | **69.9%** | **2,573** | **70.3%** |

**Quarterly summary:**

| Quarter | Revenue | % of Total | Orders | % of Orders |
| --- | --- | --- | --- | --- |
| Q1 2026 (Jan–Mar) | CHF 43,947 | 16.3% | 611 | 16.7% |
| Q2 2026 (Apr–Jun) | CHF 41,909 | 15.6% | 529 | 14.4% |
| Q3 2025 (Jul–Sep) | CHF 34,095 | 12.7% | 458 | 12.5% |
| Q3 2026 (Jul–Sep) | CHF 43,881 | 16.3% | 572 | 15.6% |
| Q4 2025 (Oct–Dec) | CHF 46,753 | 17.4% | 630 | 17.2% |
| Q4 2026 (Oct–Dec) | CHF 58,459 | 21.7% | 861 | 23.5% |

**Headline takeaways** (see also Key Data Insights in the main README):

- **Revenue concentration**: Q4 2026 (CHF 58,459) is the largest single quarter, accounting for 21.7% of total revenue. Q4 2025 contributed 17.4%, making the two Q4 periods combined responsible for 39.1% of total revenue.
- **VIP leverage**: 26.9% of 2026 orders came from VIPs, driving 36.0% of 2026 revenue.
