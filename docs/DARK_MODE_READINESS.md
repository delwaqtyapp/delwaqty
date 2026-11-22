# Dark-Mode Readiness Checklist (Batch 5.3)
Scope: merchant / driver / admin surfaces. Customer flavor is frozen (owner
decision 2026-11-22) — no customer visual work, including dark mode.

## Token foundation
- [x] All colors flow through AppColors tokens (design guard enforces no
      raw Color(0x…) outside app_theme.dart; baseline ratcheted at 385).
- [x] Text styles flow through AppTextStyles (batch 1.1, scoped off customer).
- [x] Radii via AppRadius; shadows via AppShadows.

## Per-surface status (vs raw-hex baseline 2026-11-22)
- [x] 1.1 text theme — merchant/driver/admin only (2fc4245)
- [x] 3.1 driver offer sheet — tokenized (58e90d7)
- [x] 3.2 merchant order card — tokenized (1a98ef9)
- [x] 3.3 driver dashboard — tokenized (52e63fc)
- [x] 4.1 admin sidebar — derives from AppColors (1b0975c)
- [x] 4.3 POS tiles/badge/charge bar — tokenized (63a4034)
- [ ] 5.1 auth screens — branding done (e960591); exact-token color sweep
      pending (many raw values have no exact token — map visually, non-customer only)
- [ ] 1.4 admin dashboards & dialogs — exact-match token migration pending
- [ ] Store setup wizard — step indicator tokenized; full color sweep pending

## Blockers for a dark palette
1. Semantic token set is light-only: AppColors has no dark counterparts —
   introducing dark mode needs a ThemeExtension or AppColors.dark twin, then
   widgets must read from context rather than the const class.
2. Hard-coded light surfaces assumed by gradient/scrim overlays (hero image
   scrims assume dark overlay on light surface).
3. Shadows on dark surfaces need lower opacity variants.
4. Status colors (success/error) need contrast-checked dark variants.
5. Admin web canvas (1240px shell) assumes AppColors.canvas light gray.

## Decision needed
Dark mode is a palette + plumbing project, not a sweep. Recommend deferring
until after launch unless the owner wants it for merchant/driver first.
