/// Single source of truth for the Windows cashier license prices (EGP).
///
/// Owner decision, 2026-11-27: 100 / month, 250 / 3 months, 450 / 6 months,
/// 1000 / year, 2999 lifetime. Every screen that shows a price reads it from
/// here, so a future promotion (for example a discount on lifetime) is a
/// change to this one file.
const cashierPlanPricesEgp = <String, int>{
  'core_monthly': 100,
  'core_quarterly': 250,
  'core_semiannual': 450,
  'core_annual': 1000,
  'core_lifetime': 2999,
};

/// Price in EGP for a plan, or null for plans with no price (the free trial).
int? cashierPlanPriceEgp(String plan) => cashierPlanPricesEgp[plan];
