connection: "bigquery_connection"

include: "/lookml/views/*.view.lkml"

datagroup: default_datagroup {
  sql_trigger: SELECT MAX(order_date) FROM ${orders.SQL_TABLE_NAME} ;;
  max_cache_age: "24 hours"
}

explore: orders {
  view_name: orders
  label: "Order Performance"
  group_label: "E-Commerce"
  persist_with: default_datagroup

  description: >
    Order-grain Explore for monitoring sales, order volume, basket size,
    customer segmentation and customer behaviour. Grain: one row per order.
    Revenue measures are safe to aggregate without fan-out because the Explore
    is at exactly one-row-per-order grain.

  # NOTE: has_complete_12_month_history is available as a filter dimension.
  # Orders before 2026-07-09 have an incomplete 12-month lookback and may
  # understate historical counts. Filter to "Yes" to exclude those rows.
}

explore: order_lines {
  view_name: order_lines
  label: "Product Performance"
  group_label: "E-Commerce"
  persist_with: default_datagroup

  description: >
    Product/order-line Explore for analysing sales by product, customer,
    and segment. Grain: one row per order × product. Use this Explore for
    product-level revenue, units, and customer analysis. Safe to aggregate
    because each row is a single product line.

  join: orders {
    type: left_outer
    relationship: many_to_one
    sql_on: ${order_lines.order_id} = ${orders.order_id} ;;
    fields: [orders.order_segmentation, orders.customer_profile]
  }
}
