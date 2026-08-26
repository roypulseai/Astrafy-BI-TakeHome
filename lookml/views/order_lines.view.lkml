view: order_lines {
  # sql_table_name should be configured per environment.
  sql_table_name: `thtask.recruitment_analytics.mart_order_lines` ;;

  dimension: order_id {
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

  dimension: product_id {
    type: number
    label: "Product ID"
    description: "Unique product identifier."
    sql: ${TABLE}.product_id ;;
  }

  dimension_group: order_date {
    type: time
    datatype: date
    convert_tz: no
    description: "Date the order was placed."
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.order_date ;;
  }

  dimension: quantity {
    type: number
    description: "Quantity of this product purchased in the order line."
    sql: ${TABLE}.quantity ;;
  }

  dimension: net_sales {
    hidden: yes
    type: number
    description: "Net sales for this product line. Use total_net_sales measure for reporting."
    sql: ${TABLE}.net_sales ;;
    value_format_name: decimal_2
  }

  dimension: order_segmentation {
    type: string
    label: "Order Customer Segment"
    description: >
      Customer segment at the time of each order, based on orders placed
      during the preceding 12 months (excluding the current order):
      New = 0 prior orders, Returning = 1-3, VIP = 4+.
    sql: ${TABLE}.order_segmentation ;;
    suggestions: ["New", "Returning", "VIP"]
  }

  dimension: customer_profile {
    type: string
    label: "Current Customer Segment"
    description: >
      Customer's current segment based on their latest order.
      Stable across all orders for a given customer.
    sql: ${TABLE}.customer_profile ;;
    suggestions: ["New", "Returning", "VIP"]
  }

  dimension: has_complete_12_month_history {
    hidden: yes
    type: yesno
    description: "Whether the full 12-month lookback falls within the dataset."
    sql: ${TABLE}.has_complete_12_month_history ;;
  }

  dimension: revenue_per_unit {
    type: number
    description: "Net sales divided by quantity for this order line."
    sql: ${TABLE}.revenue_per_unit ;;
    value_format_name: decimal_2
  }

  # ── Core Measures ──────────────────────────────────────────────────────────

  measure: total_net_sales {
    type: sum
    description: "Total revenue across all product lines."
    sql: ${net_sales} ;;
    value_format_name: decimal_2
    drill_fields: [order_line_detail*]
  }

  measure: total_quantity {
    type: sum
    description: "Total units sold across all product lines."
    sql: ${quantity} ;;
    drill_fields: [order_line_detail*]
  }

  measure: order_count {
    type: count_distinct
    description: "Number of distinct orders containing at least one product line."
    sql: ${order_id} ;;
    drill_fields: [order_line_detail*]
  }

  measure: unique_customers {
    type: count_distinct
    description: "Number of distinct customers who purchased."
    sql: ${customer_id} ;;
  }

  measure: unique_products {
    type: count_distinct
    description: "Number of distinct products sold."
    sql: ${product_id} ;;
  }

  measure: average_revenue_per_unit {
    type: number
    description: "Total revenue / total units sold."
    sql: ${total_net_sales} / NULLIF(${total_quantity}, 0) ;;
    value_format_name: decimal_2
  }

  measure: average_quantity_per_order {
    type: number
    description: "Total units / distinct orders (average basket size at product level)."
    sql: ${total_quantity} / NULLIF(${order_count}, 0) ;;
    value_format_name: decimal_2
  }

  # ── Segment-Specific Measures ──────────────────────────────────────────────

  measure: new_customer_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "New"]
    description: "Total revenue from product lines classified as New."
    value_format_name: decimal_2
  }

  measure: returning_customer_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "Returning"]
    description: "Total revenue from product lines classified as Returning."
    value_format_name: decimal_2
  }

  measure: vip_revenue {
    type: sum
    sql: ${net_sales} ;;
    filters: [order_segmentation: "VIP"]
    description: "Total revenue from product lines classified as VIP."
    value_format_name: decimal_2
  }

  # ── Detail Sets ────────────────────────────────────────────────────────────

  set: order_line_detail {
    fields: [
      order_id,
      product_id,
      order_date_date,
      quantity,
      net_sales,
      revenue_per_unit,
      order_segmentation,
      customer_profile
    ]
  }
}
