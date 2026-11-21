-- 227 (LOW-13): platform_commissions.currency defaulted to 'SAR' on an
-- EGP-only platform. Every current insert passes the currency explicitly and
-- all 7 prod rows are EGP, but any future insert path that omits it would
-- silently book revenue in the wrong currency.
ALTER TABLE public.platform_commissions
  ALTER COLUMN currency SET DEFAULT 'EGP';
