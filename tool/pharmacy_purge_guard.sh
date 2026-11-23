#!/usr/bin/env bash
# Fails if any pharmacy/medicine trace remains in the four Play-bound apps
# (customer, provider, driver, admin): sources, tests, l10n and assets.
# The Windows cashier (pos/) and the database (supabase/) are covered by
# their own removal work and are out of scope here.
set -euo pipefail

# The merchant data source keeps three protective `.neq('type', 'pharmacy')`
# filters so legacy rows of the retired type can never surface in customer
# discovery. They are allowlisted here and removed by the DB cleanup PR.
hits=$(grep -rniE 'pharmac|صيدل|drug_catalog|drugImport' \
  lib test assets 2>/dev/null \
  | grep -v "\.neq('type', 'pharmacy')" || true)

if [ -n "$hits" ]; then
  echo "FAIL: pharmacy trace found in Play-bound app sources:"
  echo "$hits"
  exit 1
fi
echo "pharmacy purge guard: clean"
