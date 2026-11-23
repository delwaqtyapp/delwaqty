# Windows run-test checklist — Delwaqty POS (WPF)

The WPF shell is compile-verified on Linux but the UI can only be exercised on
Windows. Run this checklist on a real Windows machine before any store rollout.
Each item names the code path it exercises and the expected result.

## 0. Test matrix
- [ ] Windows 10/11, .NET 8 build (`net8.0-windows`).
- [ ] Windows 7 SP1, .NET Framework 4.8 build (`net48`) — the weak-PC fallback.
- [ ] A screen at 1366x768 (common shop resolution) with 100% scaling.
- [ ] Arabic UI culture (ar-EG): layout mirrors RTL, no clipped text.

## 1. First run / activation
- [ ] App starts with no config: shows the activation screen, not a crash.
- [ ] Enter a trial key (DLWQ1.…): `SyncClient.DeviceLink` → `cashier_device_link`.
      Expected: store name/address/phone shown, plan = trial, expiry shown.
- [ ] Wrong key: shows "مفتاح غير معروف" (UNKNOWN_KEY), no crash, retry allowed.
- [ ] Key already bound to another PC: shows the BOUND_TO_OTHER_DEVICE message.
- [ ] Restart the app: no activation prompt (LocalLicenseSeal restored), lands
      on the main screen.

## 2. Catalog
- [ ] First sync pulls the store's products (PullApplier → RetailCatalogCache).
      Expected: product count matches the web dashboard.
- [ ] Search by barcode: exact product, top hit.
- [ ] Search Arabic name with a different alef form (ارز vs أرز): found.
- [ ] Search with a spelling slip (ديتولل): found via similarity fallback.

## 3. Selling (online)
- [ ] Build a sale of 3 items, pay exact cash: receipt totals correct, stock
      decrements, sale visible in the web dashboard's pos_sales.
- [ ] Split payment (cash + InstaPay): pos_sale_payments has both rows.
- [ ] Deferred sale (أجل) to a named customer: debt ledger charge appears,
      customer balance correct on next pull.
- [ ] Partial debt payment: balance decreases by exactly the payment.
- [ ] Void a sale: stock restored, void_restore move logged, dashboard shows
      the sale voided.

## 4. Offline-first (the core promise)
- [ ] Pull the network cable / disable Wi-Fi. Sell 2 items: sale completes
      locally, queued in the outbox (OutboxStore).
- [ ] Reconnect: SyncEngine flushes; each op reported synced; dashboard shows
      the sales with their original offline timestamps.
- [ ] Kill the app mid-queue, relaunch: pending ops still flush (no loss).
- [ ] Push the same batch twice (retry): server reports duplicates, no double
      sales (idempotency on client op ids).

## 5. جرد / صرف
- [ ] Stock count (جرد): enter a counted qty; products.stock_quantity updates;
      count_adjustment move logged with the delta.
- [ ] Dispense (صرف) an item without a sale: dispense move logged, stock drops.

## 6. Daily close
- [ ] Close the shift with counted cash: expected vs closing cash difference
      shown; totals JSON matches the day's sales by method.

## 7. Grace / expiry
- [ ] System clock past expiry: app enters grace mode (grace_days), warns in
      Arabic, still allows sales (offline grace by design).
- [ ] Past grace: activation screen returns with EXPIRED reason.

## Sign-off
| Build | Machine | Tester | Date | Pass/Fail + notes |
|---|---|---|---|---|
