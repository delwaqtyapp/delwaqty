// whatsapp-password-reset: password reset authorized ONLY by a
// webhook-verified WhatsApp OTP challenge (migration 387).
//
// Flow: the app calls request_whatsapp_otp(phone, 'password_reset'), the
// user sends the shown code from their own WhatsApp to the platform
// number, the whatsapp-webhook marks it verified, and the app then posts
// { phone, challenge, new_password } here. consume_whatsapp_reset_challenge
// (service-role) atomically validates + consumes the one-time challenge and
// returns the auth user id; we set the new password with the admin API.
//
// Deploy: supabase functions deploy whatsapp-password-reset
// (JWT verification stays ON: the app calls this with the anon key.)
//
// Anti-enumeration: every failure returns the same RESET_NOT_VERIFIED, so
// the endpoint reveals nothing about phones, accounts, or challenges.

import { createClient } from "npm:@supabase/supabase-js@2.39.0";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
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
  if (req.method !== "POST") return json({ error: "method" }, 405);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, code: "INVALID_INPUT" }, 400);
  }

  const phone = normalizeEgyptPhone(String(body?.phone ?? ""));
  const challenge = String(body?.challenge ?? "");
  const password = String(body?.new_password ?? "");

  if (
    phone.length < 10 ||
    !/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(challenge)
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
  // burns the challenge on purpose: the user simply requests a fresh code,
  // and a challenge can never authorize two resets.
  const { data: userId, error } = await supabase.rpc(
    "consume_whatsapp_reset_challenge",
    { p_phone: phone, p_challenge: challenge },
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

  return json({ ok: true });
});
