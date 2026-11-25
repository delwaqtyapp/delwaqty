// auth-login-identifier: session-only login for phone, username or email.
//
// Replaces the client-side resolve-then-sign-in flow: the app used to
// call the anon-granted lookup_email_by_phone / lookup_email_by_username
// RPCs to turn an identifier into an email, then sign in itself. Those
// RPCs hand an email to anyone who guesses an identifier - an
// email-harvest channel. Here the client sends (identifier, password)
// and gets back ONLY session tokens:
//
//   identifier -> auth_login_resolve_email (service-role RPC, server)
//              -> GoTrue signInWithPassword (server-side anon client)
//              -> { access_token, refresh_token, expires_in, token_type }
//
// The email never leaves the server, and the response NEVER contains a
// user object or an email address.
//
// Anti-enumeration contract:
//   - Unknown identifier and wrong password return the IDENTICAL status
//     (401) and body ({ "error": "invalid_credentials" }).
//   - Failure responses are padded to a minimum duration
//     (AUTH_LOGIN_MIN_RESPONSE_MS, default 800ms) so the missing GoTrue
//     call on the unknown-identifier path is not a timing oracle.
//   - Lockout before any work: auth_login_gate allows at most 5 failures
//     per identifier and 20 per IP per 10 minutes; over the limit the
//     answer is 429 { "error": "too_many_attempts" } with no resolution
//     and no password check. (429 is deliberately distinct: it fires
//     regardless of whether the identifier exists.)
//
// Secrets: SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
// are provided by the runtime. Nothing else.
//
// Deploy: supabase functions deploy auth-login-identifier --no-verify-jwt
// (--no-verify-jwt: at login time the caller has no session yet.)

import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

const INVALID = { error: "invalid_credentials" };
const MIN_RESPONSE_MS = Number(
  Deno.env.get("AUTH_LOGIN_MIN_RESPONSE_MS") ?? "800",
);

// Same normalization the database applies (_normalize_egypt_phone):
// keep digits, map 01xxxxxxxxx / 1xxxxxxxxx to +201xxxxxxxxx. Used only
// for the lockout key, never for resolution (the SQL resolver does that).
function normalizeEgyptPhone(raw: string): string {
  let d = raw.replace(/\D/g, "");
  if (d.startsWith("0020")) d = d.slice(2);
  if (d.startsWith("20")) return `+${d}`;
  if (d.startsWith("0")) return `+2${d}`;
  if (d.startsWith("1") && d.length === 10) return `+20${d}`;
  return `+${d}`;
}

// Lockout bucket key: one key per account identifier, case- and
// format-insensitive, so an attacker cannot reset the counter by
// re-casing a username or reformatting a phone.
function identifierKey(identifier: string): string {
  const trimmed = identifier.trim();
  if (trimmed.includes("@")) return `email:${trimmed.toLowerCase()}`;
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length >= 9 && /^[+0-9 ()-]+$/.test(trimmed)) {
    return `phone:${normalizeEgyptPhone(trimmed)}`;
  }
  return `uname:${trimmed.toLowerCase()}`;
}

function callerIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  return fwd.split(",")[0]?.trim() || "unknown";
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({}, 200);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const started = Date.now();

  let identifier: string;
  let password: string;
  try {
    const body = await req.json();
    identifier = String(body?.identifier ?? "").trim();
    password = String(body?.password ?? "");
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  if (
    identifier === "" || identifier.length > 254 ||
    password === "" || password.length > 128
  ) {
    return json({ error: "bad_request" }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = createClient(url, serviceKey);

  const key = identifierKey(identifier);
  const ip = callerIp(req);

  // Lockout gate before any resolution or password work.
  const { data: allowed, error: gateError } = await service.rpc(
    "auth_login_gate",
    { p_identifier_key: key, p_ip: ip },
  );
  if (gateError) {
    console.error("auth-login gate error", gateError.code ?? "unknown");
    return json({ error: "temporarily_unavailable" }, 503);
  }
  if (allowed !== true) {
    return json({ error: "too_many_attempts" }, 429);
  }

  // Padded failure: unknown identifier and wrong password are
  // indistinguishable in status, body and approximate timing.
  const fail = async (): Promise<Response> => {
    await service.rpc("auth_login_record", {
      p_identifier_key: key,
      p_ip: ip,
      p_success: false,
    });
    const elapsed = Date.now() - started;
    // Floor is MIN + jitter: jitter only ever widens the pad, never
    // narrows it below the minimum.
    const target = MIN_RESPONSE_MS + Math.floor(Math.random() * 100);
    if (elapsed < target) {
      await sleep(target - elapsed);
    }
    return json(INVALID, 401);
  };

  const { data: email, error: resolveError } = await service.rpc(
    "auth_login_resolve_email",
    { p_identifier: identifier },
  );
  if (resolveError) {
    console.error("auth-login resolve error", resolveError.code ?? "unknown");
    return json({ error: "temporarily_unavailable" }, 503);
  }
  if (typeof email !== "string" || email === "") {
    return await fail();
  }

  const anon = createClient(url, anonKey);
  const { data: session, error: signInError } =
    await anon.auth.signInWithPassword({ email, password });
  if (signInError || !session?.session) {
    return await fail();
  }

  await service.rpc("auth_login_record", {
    p_identifier_key: key,
    p_ip: ip,
    p_success: true,
  });

  const s = session.session;
  // Session tokens only: no user object, no email, nothing enumerable.
  return json({
    access_token: s.access_token,
    refresh_token: s.refresh_token,
    expires_in: s.expires_in,
    token_type: s.token_type,
  }, 200);
});
