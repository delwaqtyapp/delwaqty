# Delwaqty cashier: known limits of this release (trial build)

Honest list, so nobody finds them in front of a customer.

- No refund flow. A whole sale can be voided (client `sale_void` op, local
  `MarkVoided`), but there is no partial refund or return-to-customer flow.
- No in-app update. A new cashier build is installed by hand over the old one.
- Offline grace uses the local PC clock. Setting the clock back can extend the
  offline grace period until the next successful online license check.
- Cash over the amount due is accepted in the payment dialog; the cashier is
  shown the change and only the amount due is recorded. Other methods still
  reject overpayment.
- The data folder is `C:\ProgramData\DelwaqtyPos`. It is locked to SYSTEM,
  Administrators and the Windows user who runs the app. One dedicated Windows
  account per shop PC is the supported model. If the lock-down fails the app
  warns on start.
- Windows runtime behavior has not yet been proven on a real PC. Run
  `windows-proof-checklist.md` once with test data before any real shop day.
- Every 60 s the app pulls the full product and customer list (no
  incremental pull yet). Fine for a test merchant; heavy for a large catalog.
- A product deleted or hidden on the platform stays sellable on the PC until
  the local cache is cleared, and the shown stock can jump back for up to a
  minute after offline sales (the pull overwrites it with the server value).
- Numbers sent as text by the server are parsed with the PC's culture; the
  server sends JSON numbers, so this is expected to be harmless, not tested on
  an Arabic-locale Windows PC.
- Rejected sync ops are shown in the status area (first 3) and written to
  `sync-failures.log` in the data folder; there is no screen to fix or discard
  one yet.
- If the saved sign-in is lost, a "تسجيل الدخول من جديد" button appears. It
  renews the session only; it does not change the license or the merchant.
- Short license keys (454): the failed-lookup throttle is per signed-in user
  (10 per hour) and signups are open, so it slows guessing but is not a hard
  cap. A wrong key and a key that belongs to another merchant return different
  answers (UNKNOWN_KEY vs NOT_AUTHORIZED), which tells a signed-in user that a
  code exists. Accepted for the trial period; the code is useless without the
  merchant's own login.
