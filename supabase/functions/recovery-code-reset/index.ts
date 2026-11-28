// recovery-code-reset: password reset authorized ONLY by a one-time code an
// admin issued after speaking to the account holder (migration 466,
// admin_issue_recovery_code). Used while WhatsApp verification is blocked.
//
// The app posts { phone, code, new_password }. consume_recovery_code
// (service-role) atomically checks the hashed code (30 minutes, 5 wrong tries,
// single use) and returns the auth user id only when exactly one account
// holds that phone. We then set the password with the admin API and revoke
// every existing session.
//
// Deploy: supabase functions deploy recovery-code-reset (JWT verification ON).
// Anti-enumeration: every failure to verify returns RESET_NOT_VERIFIED.

import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function normalizeEgyptPhone(raw: string): string {
  let d = raw.replace(/\D/g, "");
  if (d.startsWith("0020")) d = d.slice(2);
  if (d.startsWith("20")) return `+${d}`;
  if (d.startsWith("0")) return `+2${d}`;
  if (d.startsWith("1") && d.length === 10) return `+20${d}`;
  return `+${d}`;
}

Deno.serve(async (req) => {
  // Web callers send a CORS preflight; answer it before anything else.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method" }, 405);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, code: "INVALID_INPUT" }, 400);
  }

  const phone = normalizeEgyptPhone(String(body?.phone ?? ""));
  const code = String(body?.code ?? "");
  const password = String(body?.new_password ?? "");

  if (
    phone.length < 10 ||
    !/^[0-9]{8}$/.test(code)
  ) {
    return json({ ok: false, code: "INVALID_INPUT" }, 400);
  }
  if (password.length < 8) {
    return json({ ok: false, code: "WEAK_PASSWORD" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // Atomic validate + consume. A failed password update after this point
  // burns the code on purpose: the admin issues a fresh one.
  const { data: userId, error } = await supabase.rpc(
    "consume_recovery_code",
    { p_phone: phone, p_code: code },
  );
  if (error || !userId) {
    return json({ ok: false, code: "RESET_NOT_VERIFIED" }, 403);
  }

  const { error: updateError } = await supabase.auth.admin.updateUserById(
    userId as string,
    { password },
  );
  if (updateError) {
    return json({ ok: false, code: "RESET_FAILED" }, 500);
  }

  // Revoke every existing session for this user: anyone still logged in
  // with the old credentials (including a possible hijacker) loses their
  // refresh tokens and must use the new password. revoke_user_sessions
  // (migration 388, service-role) deletes auth.sessions + refresh_tokens
  // directly; already-issued access JWTs remain valid until they expire.
  const { error: revokeError } = await supabase.rpc("revoke_user_sessions", {
    p_user_id: userId as string,
  });
  if (revokeError) {
    // Fail loudly: a reset that leaves old sessions alive is not a reset.
    return json({ ok: false, code: "SESSION_REVOKE_FAILED" }, 500);
  }

  return json({ ok: true });
});
