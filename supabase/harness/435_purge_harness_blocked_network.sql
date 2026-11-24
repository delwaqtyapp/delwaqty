-- Case 4c single blocker: ONE row in the pharmacy network tables (two
-- linked pharmacy merchants). Runs AFTER 431. Both merchants are
-- inserted/kept in the 431 post-state (suspended + closed) so Gate A
-- passes and the abort is attributable to Guard 1 alone.
BEGIN;
INSERT INTO public.merchants (id, name, type, status, is_open)
VALUES ('43500000-0000-4000-8000-0000000000f9', 'harness pharmacy B', 'pharmacy', 'suspended', false)
ON CONFLICT (id) DO UPDATE SET status = 'suspended', is_open = false;
-- 431 already suspended f1; make sure it still is (Gate A boundary).
UPDATE public.merchants SET status = 'suspended', is_open = false
 WHERE id = '43500000-0000-4000-8000-0000000000f1';
INSERT INTO public.pharmacy_links (pharmacy_a, pharmacy_b, status)
VALUES (LEAST('43500000-0000-4000-8000-0000000000f1'::uuid, '43500000-0000-4000-8000-0000000000f9'::uuid),
        GREATEST('43500000-0000-4000-8000-0000000000f1'::uuid, '43500000-0000-4000-8000-0000000000f9'::uuid), 'active')
ON CONFLICT (pharmacy_a, pharmacy_b) DO NOTHING;
COMMIT;
