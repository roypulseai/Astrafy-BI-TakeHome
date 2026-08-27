connection: "@{CONNECTION_NAME}"

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
    order segmentation and customer profile. Grain: one row per order.
    Revenue measures are safe to aggregate without fan-out because the Explore
    is at exactly one-row-per-order grain. Order segmentation classifies each
    order as New, Returning, or VIP based on the customer's order history.
    Do not mix with order-line-level measures in one query — use the Product
    Performance Explore for product metrics; join on order_id only when both
    grains are explicitly required.

  # NOTE: has_complete_12_month_history is available as a filter dimension.
  # Orders before 2026-07-09 do not have a complete 12-month lookback because
  # the supplied dataset begins on 2025-07-09. Their New/Returning/VIP
  # segmentation may therefore be inaccurate. Filter to "Yes" when analysis
  # requires a complete historical window.
}

explore: order_lines {
  view_name: order_lines
  label: "Product Performance"
  group_label: "E-Commerce"
  persist_with: default_datagroup

  description: >
    Product/order-line Explore for analysing sales by product and customer,
    with order-level segmentation available for slicing product performance.
    Grain: one row per order × product. Use this Explore for product-level
    revenue, units, and customer analysis. Each row represents a single
    order-product combination, so product-level measures are additive at this
    grain. Do not mix with order-level measures — order metrics belong in the
    Order Performance Explore; unique_customers is non-additive and should not
    be summed across segments or other dimensions.

  # order_segmentation and customer_profile are exposed directly from the
  # order_lines view (mart_order_lines already carries these order-level
  # attributes), so no join to the orders view is required here.
}
