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
