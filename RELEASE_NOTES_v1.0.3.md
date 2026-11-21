# Delwaqty v1.0.3 (build 4) — OTA

## Customer app
- Checkout launch blockers: saved-address picker with default preselect (coords included, Place Order works without a map pin), delivery fee shown in the order summary and included in the total (matches what the server charges), map picker no longer crashes on web (graceful placeholder + GPS timeout).
- Arabic search bar truncation fixed; cart snackbar launch blocker fixed.

## Driver app
- App bar title shortened ("Delivery Das…" fixed), Withdraw button legible when disabled, offline delivery hub has an empty state instead of a blank area.

## Backend (already live)
- Order dispatch lifecycle: accept_order ride propagation fixed (orders no longer show ASSIGNED with a driverless ride), driver accept no longer dies on vehicles with make/model (23514), reject/accept deadlock (40P01) fixed.
- Canonical server-priced checkout: card/wallet payment methods accepted; client-supplied prices ignored everywhere.
- Security lockdown: wallet/topup/refund and pricing RPCs no longer client-callable (C4/C5).
- Redispatch sweep: rides stuck searching are re-offered every 2 minutes.

## Since the prep build (folded in)
- Checkout: server error codes (out of stock, missing delivery location, required/maxed modifier options) show as clear Arabic/English messages instead of a generic failure.
- Merchant dashboard: order cards show the customer name and the same short reference the customer sees; state-specific actions only; today's-orders count fixed.
- Driver dashboard: unified stats source; wallet card labelled "Available balance"; web no longer nags with a dead-end location settings prompt.
- Merchant POS and drug import: error text routed through friendly messages.
