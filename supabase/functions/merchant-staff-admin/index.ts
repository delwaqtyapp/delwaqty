import { createClient } from "npm:@supabase/supabase-js@2.39.0";

// merchant-staff-admin: owner-only staff account management (design v3 PR-A,
// round 3: provisioning protocol + sync completion + password proof).
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
//   - Provisioning protocol: staff_admin_provision_begin authorizes and
//     records a one-use, owner+merchant-bound provisioning row BEFORE any
//     GoTrue call (a refused attempt performs ZERO GoTrue effects). The
//     GoTrue user is created carrying app_metadata.staff_provisioning,
//     which only the service key can set, and staff_admin_provision_complete
//     consumes the row atomically only for that exact auth user, after
//     re-validating CURRENT ownership/type/branch. Any failure after begin
//     is followed by staff_admin_provision_abort (its own errors are
//     logged, never silently dropped).
//   - Sync protocol (#261/#262): set_active and reset_password arm a
//     pending sync op on the staff row; enable NEVER activates from the
//     direct RPC. The edge performs the GoTrue effects and reports the
//     outcome via staff_admin_sync_complete; only a verified completion
//     activates an enable. A GoTrue failure marks the op 'failed' - the
//     actionable blocked state the owner retries from.
//   - Password proof (#266): after every verified rotation (creation or
//     reset) the edge calls staff_admin_mark_password_rotated, which stores
//     a digest of auth.users.encrypted_password; staff_password_changed
//     clears the barrier only when the live digest differs.
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

  // Parse the body BEFORE rate limiting so a 429 can still be audited
  // against its merchant (#263). Unparseable bodies carry no merchant.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  const action = typeof body.action === "string" ? body.action : "";
  const bodyMerchant = typeof body.merchant_id === "string" ? body.merchant_id : null;

  // Refusals are always logged through the bounded audit RPC (S1/#263);
  // failures of the logging call itself never change the response.
  const logRefusal = (merchantId: unknown, reason: string) => {
    if (typeof merchantId !== "string" || !merchantId) return Promise.resolve();
    return caller.rpc("staff_admin_audit_refusal", {
      p_merchant_id: merchantId,
      p_reason: reason,
    }).then(() => {}, () => {});
  };

  // Rate limit BEFORE any work: 30/hr per owner, 60/hr per IP.
  const ip = callerIp(req);
  const [{ data: ownerOk }, { data: ipOk }] = await Promise.all([
    admin.rpc("_lookup_rate_allow", { p_k: `staff_admin:owner:${callerId}`, p_max: 30 }),
    admin.rpc("_lookup_rate_allow", { p_k: `staff_admin:ip:${ip}`, p_max: 60 }),
  ]);
  if (ownerOk !== true || ipOk !== true) {
    await logRefusal(bodyMerchant, "rate_limited");
    return json({ error: "rate_limited" }, 429);
  }

  if (action === "create_staff") {
    const merchantId = String(body.merchant_id ?? "");
    const username = String(body.username ?? "").trim();
    const fullName = String(body.full_name ?? "").trim();
    const role = String(body.role ?? "");
    const branchId = body.branch_id ? String(body.branch_id) : null;
    const phone = body.phone ? String(body.phone).trim() : null;
    // Role allowlist here too; the executor re-checks server-side. A staff
    // role can never be owner or above the caller.
    if (!["branch_manager", "cashier", "kitchen"].includes(role)) {
      await logRefusal(merchantId, "invalid_role");
      return json(REFUSED, 403);
    }

    // BEGIN authorizes and binds the attempt BEFORE any GoTrue effect
    // (#259): ownership, eligibility, flag, rate and collisions are all
    // decided at the DB boundary under the caller's JWT.
    const { data: prov, error: beginErr } = await caller.rpc(
      "staff_admin_provision_begin",
      {
        p_merchant_id: merchantId,
        p_username: username,
        p_full_name: fullName,
        p_role: role,
        p_branch_id: branchId,
        p_phone: phone,
      },
    );
    if (beginErr || !prov?.provision_id) {
      await logRefusal(merchantId, "create_staff");
      return json(REFUSED, 403);
    }
    const abortProvision = async (reason: string) => {
      const { error: abortErr } = await caller.rpc("staff_admin_provision_abort", {
        p_provision_id: prov.provision_id,
        p_reason: reason,
      });
      // Abort errors are never silently dropped (#262).
      if (abortErr) await logRefusal(merchantId, "provision");
    };

    // Fresh staff-only auth user, bound to this exact provision through
    // app_metadata (service-key only, S3). NO phone anywhere: staff phones
    // are contact data in merchant_staff and must never reach users.phone.
    // user_metadata carries no user_type: handle_new_user never trusts it.
    const password = randomPassword();
    const email = `staff_${crypto.randomUUID()}@delwaqty.app`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { staff_provisioning: prov.provision_id },
      user_metadata: { full_name: fullName },
    });
    if (createErr || !created?.user?.id) {
      await abortProvision("gotrue_failure");
      await logRefusal(merchantId, "gotrue_failure");
      return json({ error: "provision_failed" }, 502);
    }
    const authUserId = created.user.id;

    const { data: staffId, error: completeErr } = await caller.rpc(
      "staff_admin_provision_complete",
      { p_provision_id: prov.provision_id, p_auth_user_id: authUserId },
    );
    if (completeErr || !staffId) {
      // Roll back the orphaned auth user (one retry); a delete failure
      // leaves a flagged orphan whose UID is recorded in the abort reason
      // and the refusal trail (#262).
      let delErr = (await admin.auth.admin.deleteUser(authUserId)).error;
      if (delErr) delErr = (await admin.auth.admin.deleteUser(authUserId)).error;
      await abortProvision(
        delErr ? `orphan_after_delete_failure:${authUserId}` : "create_staff",
      );
      await logRefusal(merchantId, "create_staff");
      return json(REFUSED, 403);
    }

    // Password proof baseline (#266): store the digest of the one-time
    // password the edge just set. A failure here fails CLOSED (no baseline,
    // no clear) and self-heals on the next reset, so it is logged but does
    // not fail the creation.
    const { error: markErr } = await caller.rpc("staff_admin_mark_password_rotated", {
      p_staff_id: staffId,
    });
    if (markErr) await logRefusal(merchantId, "provision");

    // The one-time password is shown exactly once. No-store, never logged.
    return json(
      {
        staff_id: staffId,
        login_username: prov.login_username,
        password,
        must_change_password: true,
      },
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
      .select("id, user_id, merchant_id")
      .eq("id", staffId)
      .maybeSingle();
    if (!staff) {
      await logRefusal(bodyMerchant, "set_active");
      return json(REFUSED, 403);
    }
    // Executor FIRST (S2): arms the pending sync op under the caller.
    // Enable is fail closed: the row stays inactive until sync_complete.
    const { error: execErr } = await caller.rpc("staff_admin_set_active", {
      p_staff_id: staffId,
      p_active: active,
    });
    if (execErr) {
      await logRefusal(staff.merchant_id, "set_active");
      return json(REFUSED, 403);
    }
    // GoTrue effects with CHECKED errors (S6); the outcome is ALWAYS
    // reported back so the op never dangles (#261/#262).
    const reportSync = async (ok: boolean) => {
      const { error: syncErr } = await caller.rpc("staff_admin_sync_complete", {
        p_staff_id: staffId,
        p_op: active ? "enable" : "disable",
        p_ok: ok,
      });
      return !syncErr;
    };
    let goErr: unknown = null;
    if (active) {
      const { error: revErr } = await admin.rpc("revoke_user_sessions", {
        p_user_id: staff.user_id,
      });
      if (!revErr) {
        const { error: banErr } = await admin.auth.admin.updateUserById(staff.user_id, {
          ban_duration: "none",
        });
        goErr = banErr;
      } else {
        goErr = revErr;
      }
    } else {
      const { error: banErr } = await admin.auth.admin.updateUserById(staff.user_id, {
        ban_duration: "876000h",
      });
      if (!banErr) {
        const { error: revErr } = await admin.rpc("revoke_user_sessions", {
          p_user_id: staff.user_id,
        });
        goErr = revErr;
      } else {
        goErr = banErr;
      }
    }
    const syncOk = await reportSync(!goErr);
    if (goErr) return json({ error: "provision_failed" }, 502);
    if (!syncOk) return json({ error: "provision_failed" }, 502);
    return json({ ok: true });
  }

  if (action === "reset_password") {
    const staffId = String(body.staff_id ?? "");
    const { data: staff } = await caller
      .from("merchant_staff")
      .select("id, user_id, merchant_id")
      .eq("id", staffId)
      .maybeSingle();
    if (!staff) {
      await logRefusal(bodyMerchant, "reset_password");
      return json(REFUSED, 403);
    }
    // Executor FIRST (S2): ownership and state are verified and recorded
    // before GoTrue is touched; an executor refusal means ZERO rotation.
    const { error: execErr } = await caller.rpc("staff_admin_record_password_reset", {
      p_staff_id: staffId,
    });
    if (execErr) {
      await logRefusal(staff.merchant_id, "reset_password");
      return json(REFUSED, 403);
    }
    const reportReset = async (ok: boolean) => {
      await caller.rpc("staff_admin_sync_complete", {
        p_staff_id: staffId,
        p_op: "reset",
        p_ok: ok,
      }).then(() => {}, () => {});
    };
    const password = randomPassword();
    const { error: upErr } = await admin.auth.admin.updateUserById(staff.user_id, {
      password,
    });
    if (upErr) {
      // Rotation failure = refusal: no password is ever returned (S2).
      await reportReset(false);
      await logRefusal(staff.merchant_id, "reset_password");
      return json({ error: "provision_failed" }, 502);
    }
    // Cut every session; the next login must use the new password.
    const { error: revErr } = await admin.rpc("revoke_user_sessions", {
      p_user_id: staff.user_id,
    });
    if (revErr) {
      // The password rotated but is withheld; the op is marked failed so
      // the owner sees the blocked state and retries (#262).
      await reportReset(false);
      await logRefusal(staff.merchant_id, "reset_password");
      return json({ error: "provision_failed" }, 502);
    }
    // Verified rotation: store the digest proof (#266) and close the op.
    const { error: markErr } = await caller.rpc("staff_admin_mark_password_rotated", {
      p_staff_id: staffId,
    });
    if (markErr) await logRefusal(staff.merchant_id, "reset_password");
    await reportReset(true);
    return json({ password, must_change_password: true }, 200, {
      "Cache-Control": "no-store",
    });
  }

  if (action === "list_staff") {
    const merchantId = String(body.merchant_id ?? "");
    // Authorization is explicit (S1/#263): an invisible merchant is a
    // logged refusal, never a silent empty list.
    const { data: merchant } = await caller
      .from("merchants")
      .select("id")
      .eq("id", merchantId)
      .maybeSingle();
    if (!merchant) {
      await logRefusal(merchantId, "list_staff");
      return json(REFUSED, 403);
    }
    const { data, error } = await caller
      .from("merchant_staff")
      .select("id, username, full_name, role, branch_id, is_active, must_change_password, created_at")
      .eq("merchant_id", merchantId)
      .order("created_at");
    if (error) {
      await logRefusal(merchantId, "list_staff");
      return json(REFUSED, 403);
    }
    return json({ staff: data ?? [] });
  }

  await logRefusal(bodyMerchant, "provision");
  return json({ error: "unknown_action" }, 400);
});
