{# 
  Maps a prior order count expression to an order  segment label.
  Thresholds are configurable via dbt_project.yml vars.
  Business rule: New = 0 prior orders, Returning = 1-3, VIP = 4+.
  The else 'Unknown' fallback is unreachable with current thresholds
  but provides a safety net against null or unexpected values.
#}
{% macro get_order_segment(prior_order_count) %}

case
    when {{ prior_order_count }} <= {{ var('new_customer_max_prior_orders') }}
        then 'New'

    when {{ prior_order_count }} between {{ var('returning_min_prior_orders') }} and {{ var('returning_max_prior_orders') }}
        then 'Returning'

    when {{ prior_order_count }} >= {{ var('vip_min_prior_orders') }}
        then 'VIP'

    else 'Unknown'
end

{% endmacro %}
