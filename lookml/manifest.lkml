project_name: "astrafy_bi"

# Environment-specific configuration.
# Values can be overridden by an importing LookML project, allowing the same
# semantic layer to be deployed against a different GCP project, dataset,
# or Looker connection without modifying view/model source files.

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

# 12-month order segmentation thresholds used by the LookML semantic layer.
# These values mirror the corresponding dbt_project.yml variables.
# LookML constants and dbt variables are independent configuration sources;
# assert_segmentation_reconciliation validates that the resulting LookML
# segmentation remains consistent with the dbt-produced segmentation.

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
