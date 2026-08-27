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
