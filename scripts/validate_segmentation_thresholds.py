"""
Validate that segmentation thresholds in dbt_project.yml and lookml/manifest.lkml are in sync.
Fails (exit 1) if they diverge — prevents the two-source-of-truth drift.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DBT_PROJECT = ROOT / "dbt_project.yml"
MANIFEST = ROOT / "lookml" / "manifest.lkml"

# Map dbt var names -> manifest constant names
MAPPING = {
    "new_customer_max_prior_orders": "NEW_CUSTOMER_MAX_PRIOR_ORDERS",
    "returning_min_prior_orders": "RETURNING_MIN_PRIOR_ORDERS",
    "returning_max_prior_orders": "RETURNING_MAX_PRIOR_ORDERS",
    "vip_min_prior_orders": "VIP_MIN_PRIOR_ORDERS",
}

def parse_dbt():
    text = DBT_PROJECT.read_text()
    out = {}
    for k in MAPPING:
        m = re.search(rf'^\s*{re.escape(k)}\s*:\s*["\']?(\d+)["\']?\s*$', text, re.MULTILINE)
        if m:
            out[k] = m.group(1)
    return out

def parse_manifest():
    text = MANIFEST.read_text()
    out = {}
    # constant: NAME { value: "X" ... }
    for m in re.finditer(r'constant:\s*(\w+)\s*\{\s*value:\s*"([^"]+)"', text):
        out[m.group(1)] = m.group(2)
    return out

dbt_vals = parse_dbt()
manifest_vals = parse_manifest()

ok = True
for dbt_key, const_name in MAPPING.items():
    dbt_v = dbt_vals[dbt_key]
    lkml_v = manifest_vals.get(const_name)
    if lkml_v is None:
        print(f"FAIL: manifest missing constant {const_name}")
        ok = False
    elif dbt_v != lkml_v:
        print(f"FAIL: {dbt_key} (dbt={dbt_v}) != {const_name} (manifest={lkml_v})")
        ok = False
    else:
        print(f"OK: {dbt_key}={dbt_v} == {const_name}={lkml_v}")

if ok:
    print("\nAll segmentation thresholds in sync.")
    sys.exit(0)
else:
    print("\nThresholds are out of sync — update both dbt_project.yml and lookml/manifest.lkml together.")
    print("Runtime drift is also caught by assert_segmentation_reconciliation.")
    sys.exit(1)
