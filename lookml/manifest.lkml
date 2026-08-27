project_name: "astrafy_bi"

# All environment-specific values are constants.
# Deploy to a new environment by overriding these constants in
# Looker's Project Settings (or via manifest.lkml import) — no
# view/model source files need to be edited.

constant: GCP_PROJECT {
  value: "thtask"
  export: override_optional
}

constant: BQ_DATASET {
  value: "recruitment_analytics"
  export: override_optional
}

constant: CONNECTION_NAME {
  value: "bigquery_connection"
  export: override_optional
}

# Segmentation thresholds — single source for LookML.
# Must be kept in sync with dbt_project.yml vars
# (new_customer_max_prior_orders, returning_min/max, vip_min).
# Changing these here propagates to lookml_order_segmentation;
# the reconciliation test (assert_segmentation_reconciliation) will
# fail if dbt and LookML diverge.

constant: NEW_CUSTOMER_MAX_PRIOR_ORDERS {
  value: "0"
  export: override_optional
}

constant: RETURNING_MIN_PRIOR_ORDERS {
  value: "1"
  export: override_optional
}

constant: RETURNING_MAX_PRIOR_ORDERS {
  value: "3"
  export: override_optional
}

constant: VIP_MIN_PRIOR_ORDERS {
  value: "4"
  export: override_optional
}
