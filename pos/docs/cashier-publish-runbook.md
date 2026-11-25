# Cashier publish runbook notes (pos-windows.yml publish job)

Operational notes for the opt-in cashier publish path. Publishing stays
disabled until `PUBLISHER_SHA` in `.github/workflows/pos-windows.yml` is
pinned (it ships `UNPINNED`, which fails closed).

## Before the FIRST publish

- `PUBLISHER_SHA` must be pinned to the reviewed commit on `master` that
  contains `tool/publish_cashier.py` (i.e. after the cashier work merges
  to master). **The pin change itself needs a code-reviewer check before
  the first publish** — the pin is the trust boundary: it decides which
  code runs with the release write token.
- The workflow must be dispatched from `refs/heads/master` (the job
  refuses otherwise).

## Reruns and retries

- A rerun of the SAME workflow run reuses the same `run_number`, so the
  versioned asset names are identical on retry. That is safe by design:
  installers and the zip are immutable and never clobbered — the
  publisher re-proves existing bytes via download + SHA-256 and skips the
  upload. A rerun that produced DIFFERENT bytes at the same run number is
  impossible (same run, same inputs); if the hash proof fails, stop and
  investigate, do not force.
- The concurrency group `delwaqty-development-publisher` (shared with the
  Flutter publisher) queues runs with `cancel-in-progress: false`. GitHub
  holds at most ONE pending run per group: dispatching a third publish
  while one runs and one waits displaces the pending one. Dispatch
  sequentially and wait for the previous publish to finish.
- The manifest merge is fail-closed: any download/auth/network/schema
  error aborts BEFORE the manifest upload, so a failed cashier publish
  cannot erase the Flutter channels. If it aborts, re-dispatch; do not
  hand-edit versions.json on the release.

## After a publish

- Confirm the round-trip output (the job prints the channel digests) and
  spot-check the release page: both installers, the zip, and
  versions.json with `cashier-net8` + `cashier-net48` entries whose
  version equals the run number.
