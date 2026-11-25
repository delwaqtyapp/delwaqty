import { createClient } from "npm:@supabase/supabase-js@2.39.0";

// merchant-staff-admin: owner-only staff account management (design v3 PR-A).
//
// Security model:
//   - JWT verification is ON for this function (default; see config.toml).
//   - The service-role key is used ONLY for GoTrue admin calls
//     (createUser / updateUserById / deleteUser) and for the dedicated
//     infrastructure RPCs _lookup_rate_allow and revoke_user_sessions
//     (388 precedent). It NEVER writes business tables: merchant_staff,
//     users and merchant_staff_events writes all go through the
//     staff_admin_* executor RPCs under the CALLER's JWT, which re-check
//     ownership and eligibility server-side and audit every action,
//     including refusals.
//   - One-time passwords are generated with crypto.getRandomValues,
//     returned ONCE with Cache-Control: no-store, never logged and never
//     written to audit rows.
//   - Rate limiting: per-owner AND per-IP buckets over the
//     _lookup_rate_allow primitive; the caller IP is the LAST
//     x-forwarded-for entry (appended by the trusted edge, 440 pattern).
//   - Errors are generic: unknown merchant/staff, not-owner and
//     collisions all return the same refusal shape (no enumeration).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...extraHeaders },
  });
}

// The LAST x-forwarded-for entry is appended by the trusted edge; earlier
// entries are client input (_lookup_caller_ip / 440 convention).
function callerIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const parts = fwd.split(",");
  return (parts[parts.length - 1] ?? "").trim() || "unknown";
}

function randomPassword(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

function loginUsername(username: string, merchantId: string): string {
  return `${username.toLowerCase()}__${merchantId.replace(/-/g, "").slice(0, 6)}`;
}

const REFUSED = { error: "request_refused" };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization") ?? "";
  // Business-data client: everything it does runs as the CALLER.
  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  // GoTrue/infra client: auth admin API + rate-limit/session RPCs only.
  const admin = createClient(supabaseUrl, serviceKey);

  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData?.user?.id) return json({ error: "unauthorized" }, 401);
  const callerId = authData.user.id;

  // Rate limit BEFORE any work: 30/hr per owner, 60/hr per IP.
  const ip = callerIp(req);
  const [{ data: ownerOk }, { data: ipOk }] = await Promise.all([
    admin.rpc("_lookup_rate_allow", { p_k: `staff_admin:owner:${callerId}`, p_max: 30 }),
    admin.rpc("_lookup_rate_allow", { p_k: `staff_admin:ip:${ip}`, p_max: 60 }),
  ]);
  if (ownerOk !== true || ipOk !== true) return json({ error: "rate_limited" }, 429);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  const action = typeof body.action === "string" ? body.action : "";

  if (action === "create_staff") {
    const merchantId = String(body.merchant_id ?? "");
    const username = String(body.username ?? "").trim();
    const fullName = String(body.full_name ?? "").trim();
    const role = String(body.role ?? "");
    const branchId = body.branch_id ? String(body.branch_id) : null;
    const phone = body.phone ? String(body.phone).trim() : null;
    // Role allowlist here too; the executor re-checks server-side. A staff
    // role can never be owner or above the caller.
    if (!["branch_manager", "cashier", "kitchen"].includes(role)) return json(REFUSED, 403);

    // Eligibility from the CALLER's DB view (A10): RLS scopes this read to
    // what the caller may see; a non-owner simply finds nothing.
    const { data: merchant } = await caller
      .from("merchants")
      .select("id, type")
      .eq("id", merchantId)
      .maybeSingle();
    // A10: refused attempts are logged (insert-only RPC; no reads, no secrets).
    const logRefusal = () =>
      caller.rpc("staff_admin_audit_refusal", {
        p_merchant_id: merchantId,
        p_reason: "create_staff",
      }).then(() => {}, () => {});
    if (!merchant) { await logRefusal(); return json(REFUSED, 403); }
    const { data: eligible } = await caller.rpc("is_cashier_type", { p_type: merchant.type });
    if (eligible !== true) { await logRefusal(); return json(REFUSED, 403); }

    // Fresh staff-only auth user. NO phone anywhere: staff phones are
    // contact data in merchant_staff and must never reach users.phone.
    const password = randomPassword();
    const email = `staff_${crypto.randomUUID()}@delwaqty.app`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { user_type: "merchant_staff", full_name: fullName },
    });
    if (createErr || !created?.user?.id) return json({ error: "provision_failed" }, 502);
    const authUserId = created.user.id;

    const login = loginUsername(username, merchantId);
    const { data: staffId, error: execErr } = await caller.rpc("staff_admin_create_staff", {
      p_merchant_id: merchantId,
      p_auth_user_id: authUserId,
      p_username: username,
      p_full_name: fullName,
      p_role: role,
      p_branch_id: branchId,
      p_phone: phone,
      p_login_username: login,
    });
    if (execErr) {
      // Roll back the orphaned auth user; log the refused attempt (A10).
      await admin.auth.admin.deleteUser(authUserId);
      await logRefusal();
      return json(REFUSED, 403);
    }
    // The one-time password is shown exactly once. No-store, never logged.
    return json(
      { staff_id: staffId, login_username: login, password, must_change_password: true },
      200,
      { "Cache-Control": "no-store" },
    );
  }

  if (action === "set_active") {
    const staffId = String(body.staff_id ?? "");
    const active = body.active === true;
    // Resolve the staff row through the caller's view (owner-or-self RLS).
    const { data: staff } = await caller
      .from("merchant_staff")
      .select("id, user_id")
      .eq("id", staffId)
      .maybeSingle();
    if (!staff) return json(REFUSED, 403);
    const { error: execErr } = await caller.rpc("staff_admin_set_active", {
      p_staff_id: staffId,
      p_active: active,
    });
    if (execErr) return json(REFUSED, 403);
    // Session hygiene via GoTrue + the 388 revocation RPC (never tables).
    if (active) {
      await admin.auth.admin.updateUserById(staff.user_id, { ban_duration: "none" });
    } else {
      await admin.auth.admin.updateUserById(staff.user_id, { ban_duration: "876000h" });
      await admin.rpc("revoke_user_sessions", { p_user_id: staff.user_id });
    }
    return json({ ok: true });
  }

  if (action === "reset_password") {
    const staffId = String(body.staff_id ?? "");
    const { data: staff } = await caller
      .from("merchant_staff")
      .select("id, user_id")
      .eq("id", staffId)
      .maybeSingle();
    if (!staff) return json(REFUSED, 403);
    const password = randomPassword();
    const { error: upErr } = await admin.auth.admin.updateUserById(staff.user_id, { password });
    if (upErr) return json({ error: "provision_failed" }, 502);
    // Cut every session; the next login must use the new password.
    await admin.rpc("revoke_user_sessions", { p_user_id: staff.user_id });
    const { error: execErr } = await caller.rpc("staff_admin_record_password_reset", {
      p_staff_id: staffId,
    });
    if (execErr) return json(REFUSED, 403);
    return json({ password, must_change_password: true }, 200, { "Cache-Control": "no-store" });
  }

  if (action === "list_staff") {
    const merchantId = String(body.merchant_id ?? "");
    const { data, error } = await caller
      .from("merchant_staff")
      .select("id, username, full_name, role, branch_id, is_active, must_change_password, created_at")
      .eq("merchant_id", merchantId)
      .order("created_at");
    if (error) return json(REFUSED, 403);
    return json({ staff: data ?? [] });
  }

  return json({ error: "unknown_action" }, 400);
});
