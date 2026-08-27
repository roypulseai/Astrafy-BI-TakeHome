view: orders {
  sql_table_name: `@{GCP_PROJECT}.@{BQ_DATASET}.mart_orders` ;;

  dimension: order_id {
    primary_key: yes
    hidden: yes
    type: number
    description: "Unique order identifier."
    sql: ${TABLE}.order_id ;;
  }

  dimension: customer_id {
    hidden: yes
    type: number
    description: "Foreign key to customer."
    sql: ${TABLE}.customer_id ;;
  }

  dimension_group: order_date {
    type: time
    datatype: date
    convert_tz: no
    description: "Date the order was placed."
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.order_date ;;
  }

  dimension: net_sales {
    hidden: yes
    type: number
    description: "Order-level net revenue (CHF) for this order. One row = one order in this Explore. Use the total_net_sales measure for reporting."
    sql: ${TABLE}.net_sales ;;
    value_format_name: decimal_2
    synonyms: [revenue, sales, amount, order total]
  }

  dimension: qty_product {
    type: number
    description: "Total quantity of products purchased in the order."
    sql: ${TABLE}.qty_product ;;
    synonyms: [units, items, basket size, quantity]
  }

  dimension: product_line_count {
    type: number
    description: "Total number of product lines (order rows) in the order. Not deduplicated — use distinct_product_count for unique SKUs."
    sql: ${TABLE}.product_line_count ;;
  }

  dimension: distinct_product_count {
    type: number
    description: "Number of distinct product SKUs in the order."
    sql: ${TABLE}.distinct_product_count ;;
  }

  dimension: prior_orders_last_12_months {
    hidden: yes
    type: number
    description: "Count of orders by the same customer during the preceding 12 months."
    sql: ${TABLE}.prior_orders_last_12_months ;;
  }

  dimension: has_complete_12_month_history {
    hidden: yes
    type: yesno
    description: >
      Whether the full 12-month lookback falls within the dataset.
      Orders before 2026-07-09 may understate prior history.
    sql: ${TABLE}.has_complete_12_month_history ;;
  }

  dimension: order_segmentation {
    type: string
    label: "Order Customer Segment"
    description: >
      Segment at order time (point-in-time). Customer segment assigned to
      this specific order based on orders placed during the preceding
      12 months (excluding the current order): New = 0 prior orders,
      Returning = 1-3, VIP = 4+. Do not conflate with customer_profile
      (latest/current state).
    sql: ${TABLE}.order_segmentation ;;
    suggestions: ["New", "Returning", "VIP"]
    synonyms: [customer type, buyer segment, cohort]
  }

  # ── LookML-Derived Segmentation ────────────────────────────────────────────
  # This dimension recomputes the segmentation rule in LookML, proving that
  # the business rule is encoded in both the warehouse (dbt) and the semantic
  # layer (LookML). A reconciliation test can verify they always agree.

  dimension: lookml_order_segmentation {
    type: string
    label: "LookML-Derived Segment"
    description: >
      Segment recomputed in LookML from prior_orders_last_12_months using
      the same thresholds as the dbt macro: New = 0, Returning = 1-3,
      VIP = 4+. Used to validate that warehouse and semantic-layer
      segmentation always agree.
    sql:
      case
        when ${prior_orders_last_12_months} <= 0 then 'New'
        when ${prior_orders_last_12_months} between 1 and 3 then 'Returning'
        when ${prior_orders_last_12_months} >= 4 then 'VIP'
        else 'Unknown'
      end ;;
    suggestions: ["New", "Returning", "VIP"]
  }

  dimension: segmentation_reconciliation {
    hidden: yes
    type: yesno
    description: >
      True when the warehouse-computed order_segmentation matches the
      LookML-derived lookml_order_segmentation. Should always be true.
    sql: ${order_segmentation} = ${lookml_order_segmentation} ;;
  }

  dimension: customer_profile {
    type: string
    label: "Current Customer Segment"
    description: >
      Latest/current customer state based on the customer's most recent order
      in the dataset. Stable across all orders for a given customer
      (unlike order_segmentation which is point-in-time per order).
      Useful for analysing revenue by current customer type.
    sql: ${TABLE}.customer_profile ;;
    suggestions: ["New", "Returning", "VIP"]
  }

  # ── Core Measures ──────────────────────────────────────────────────────────

  measure: order_count {
    type: count
    description: "Total number of orders. Safe to aggregate because the Explore is at one-row-per-order grain."
    drill_fields: [order_detail*]
    synonyms: [order volume, number of orders, count of orders]
  }

  measure: total_net_sales {
    type: sum
    description: >
      Total net sales across orders. Safe to aggregate in the Orders Explore
      because the underlying model contains exactly one row per order.
    sql: ${net_sales} ;;
    value_format_name: decimal_2
    drill_fields: [order_detail*]
    synonyms: [total revenue, gross sales, total sales]
  }

  measure: average_order_value {
    type: average
    description: "Average order value = total revenue / orders (total_net_sales / order_count). Not an average of averages."
    sql: ${net_sales} ;;
    value_format_name: decimal_2
    drill_fields: [order_detail*]
    synonyms: [AOV, average basket, mean order value]
  }

  measure: total_products {
    type: sum
    description: "Total quantity of products sold across all orders."
    sql: ${qty_product} ;;
  }

  measure: average_products_per_order {
    type: average
    description: >
      Average quantity of products per order (basket size). Because this Explore
      is at one-row-per-order grain, this is the average of order quantities.
    sql: ${qty_product} ;;
    value_format_name: decimal_2
  }

  measure: unique_customers {
    type: count_distinct
    description: "Number of distinct customers who placed orders. Non-additive — do not sum across segments or time buckets; always recompute distinct."
    sql: ${customer_id} ;;
  }

  # ── Segment-Specific Measures ──────────────────────────────────────────────

  measure: new_customer_orders {
    type: count
    filters: [order_segmentation: "New"]
    description: "Orders classified as New at the time of purchase (0 prior orders in 12 months)."
  }

  measure: returning_customer_orders {
    type: count
    filters: [order_segmentation: "Returning"]
    description: "Orders classified as Returning at the time of purchase (1-3 prior orders in 12 months)."
  }

  measure: vip_orders {
    type: count
    filters: [order_segmentation: "VIP"]
    description: "Orders classified as VIP at the time of purchase (4+ prior orders in 12 months)."
  }

  measure: new_customer_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "New"]
    description: "Total revenue from orders classified as New."
    value_format_name: decimal_2
  }

  measure: returning_customer_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "Returning"]
    description: "Total revenue from orders classified as Returning."
    value_format_name: decimal_2
  }

  measure: vip_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "VIP"]
    description: "Total revenue from orders classified as VIP."
    value_format_name: decimal_2
  }

  # ── Detail Sets ────────────────────────────────────────────────────────────

  set: order_detail {
    fields: [
      order_id,
      customer_id,
      order_date_date,
      net_sales,
      qty_product,
      order_segmentation,
      customer_profile
    ]
  }
}
