# Cashier server rules the client must know (migrations 346-348)

These change what the server does with what the client sends. The wire
payloads are unchanged; the server's interpretation is not.

## Sale repricing (#26)
- Any line whose `product_id` resolves to a store product is priced by the
  SERVER (products.price via the shared pricing helper). The client's
  unit_price/total for that line is replaced; `repriced: true` on the line.
- Lines with no resolvable product (quick lines sold offline) keep
  the client price and are stored with `client_priced: true` — quarantine
  flag for review dashboards.
- pos_sales.subtotal/discount/total_amount are server-computed; commission
  is charged on the server total.
- The per-op result for a sale now returns
  `{ok, sale_id, total, repriced, client_priced}`. The client should surface
  repriced/client_priced counts to the cashier ("السعر اتحدّث من السيرفر").
- Client totals are still needed offline for display; they are just no
  longer authoritative once synced.

## أجل void reversal (#28)
- Voiding a sale no longer flips debt charges to payments. It appends
  `kind='reversal'` entries. Balance math (charge - payment - reversal) is
  unchanged in `cashier_sync_pull`.

## Sale timestamps (#30)
- pos_sales.created_at is always server now(). The offline capture time is
  in created_offline_at only. Sort reports by created_offline_at when the
  cashier's day matters.

## Stock clamp vs void (#31)
- Sale lines carry `stock_applied`: the clamped amount actually decremented.
  Void restores only that amount (a `count_adjustment` move corrects the
  rest). Stock can no longer inflate through sell-5-with-2-then-void.

## payment_method (#347)
- pos_sales.payment_method now also allows 'card', 'deferred', 'mixed'.
  Split detail remains in pos_sale_payments.

## License issuance (#27)
- Owners can self-issue `trial` only. Paid plans return
  `PAID_PLANS_REQUIRE_ADMIN` and are issued by the platform after payment.

