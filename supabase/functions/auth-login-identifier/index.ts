// auth-login-identifier: session-only login for phone, username or email.
//
// Replaces the client-side resolve-then-sign-in flow: the app used to
// call the anon-granted lookup_email_by_phone / lookup_email_by_username
// RPCs to turn an identifier into an email, then sign in itself. Those
// RPCs hand an email to anyone who guesses an identifier - an
// email-harvest channel. Here the client sends (identifier, password)
// and gets back ONLY session tokens:
//
//   identifier -> auth_login_begin (atomic attempt reservation)
//              -> auth_login_resolve_email (service-role RPC, server)
//              -> GoTrue signInWithPassword (server-side anon client)
//              -> { access_token, refresh_token, expires_in, token_type }
//
// Contract: no response contains a standalone email address or a user
// object, and no email is disclosed before successful authentication.
// (The signed access JWT itself carries whatever claims GoTrue issues,
// including email/phone - those are part of the credential and are NOT
// stripped.)
//
// Anti-enumeration:
//   - Unknown identifier and wrong password return the IDENTICAL status
//     (401) and body ({ "error": "invalid_credentials" }), and the
//     unknown-identifier path performs a dummy GoTrue password check so
//     timing matches the real one. Failure responses are additionally
//     padded to a minimum duration (AUTH_LOGIN_MIN_RESPONSE_MS,
//     default 800ms) plus jitter.
//   - Lockout BEFORE any resolution or password work: auth_login_begin
//     reserves the attempt under advisory-lock serialization - at most
//     5 failures per identifier bucket and 20 per IP per 10 minutes can
//     ever be reserved; over the limit the answer is 429
//     { "error": "too_many_attempts" } with no further work.
//   - Identifier buckets collapse every accepted spelling to one key:
//     phones by last 10 digits (rotating the country prefix cannot
//     reset the counter), usernames and emails lowercased.
//   - The caller IP is the LAST x-forwarded-for entry - the one the
//     trusted edge appends (_lookup_caller_ip convention); leading
//     entries are client-controlled and ignored.
//
// Failure policy (fail closed):
//   - Any RPC error, accounting failure, GoTrue availability error,
//     timeout or throw maps to a controlled 503
//     { "error": "temporarily_unavailable" } - never to a 401 (which
//     would let an attacker distinguish backend outages) and never to
//     issued tokens. Tokens are returned only after the attempt's
//     success accounting has been durably recorded.
//   - External calls are bounded: the GoTrue client uses a 5s fetch
//     timeout; service RPCs use a 10s timeout.
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
  "Access-Control-Allow-Headers": "content-type, authorization, apikey, x-client-info",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

const INVALID = { error: "invalid_credentials" };
const UNAVAILABLE = { error: "temporarily_unavailable" };
const MIN_RESPONSE_MS = Number(
  Deno.env.get("AUTH_LOGIN_MIN_RESPONSE_MS") ?? "800",
);
const GOTRUE_TIMEOUT_MS = 5000;
const RPC_TIMEOUT_MS = 10000;

// Same normalization the database applies (_normalize_egypt_phone):
// keep digits, map 01xxxxxxxxx / 1xxxxxxxxx to +201xxxxxxxxx.
function normalizeEgyptPhone(raw: string): string {
  let d = raw.replace(/\D/g, "");
  if (d.startsWith("0020")) d = d.slice(2);
  if (d.startsWith("20")) return `+${d}`;
  if (d.startsWith("0")) return `+2${d}`;
  if (d.startsWith("1") && d.length === 10) return `+20${d}`;
  return `+${d}`;
}

// Lockout bucket key: one key per identifier, collapsing every spelling
// the resolver accepts. Phones key on the last 10 digits of the
// NORMALIZED form: all Egyptian spellings (01x, +201x, 00201x, spaced)
// normalize to the same +201xxxxxxxxx and share one tail, and rotating
// the country prefix cannot open a fresh bucket. Usernames and emails
// lowercase.
function identifierKey(identifier: string): string {
  const trimmed = identifier.trim();
  if (trimmed.includes("@")) return `email:${trimmed.toLowerCase()}`;
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length >= 9 && /^[+0-9 ()-]+$/.test(trimmed)) {
    const normDigits = normalizeEgyptPhone(trimmed).replace(/\D/g, "");
    return `phone:${normDigits.slice(-10)}`;
  }
  return `uname:${trimmed.toLowerCase()}`;
}

// The LAST x-forwarded-for entry is appended by the trusted edge;
// earlier entries are client input (_lookup_caller_ip convention).
function callerIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const parts = fwd.split(",");
  return (parts[parts.length - 1] ?? "").trim() || "unknown";
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function timedFetch(timeoutMs: number) {
  return (input: RequestInfo | URL, init?: RequestInit) =>
    fetch(input, { ...init, signal: AbortSignal.timeout(timeoutMs) });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// One shared classifier for BOTH the real and the dummy GoTrue calls:
// a credential rejection is ONLY an explicit 400/401/422; everything
// else - status 0/undefined (AuthRetryableFetchError, network), 429,
// 5xx, a thrown fetch - is an availability failure and maps to a
// controlled 503 with the attempt recorded as failed.
type SignInOutcome =
  | { kind: "success"; session: any }
  | { kind: "credential" }
  | { kind: "unavailable" };

const CREDENTIAL_STATUSES = new Set([400, 401, 422]);

async function trySignIn(
  client: any,
  email: string,
  password: string,
): Promise<SignInOutcome> {
  try {
    const { data, error } = await client.auth.signInWithPassword({
      email,
      password,
    });
    if (!error && data?.session) return { kind: "success", session: data.session };
    if (error && CREDENTIAL_STATUSES.has(error.status)) {
      return { kind: "credential" };
    }
    console.error("auth-login gotrue error", error?.name ?? "unknown");
    return { kind: "unavailable" };
  } catch (e) {
    console.error("auth-login gotrue throw", e instanceof Error ? e.name : "unknown");
    return { kind: "unavailable" };
  }
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
  const service = createClient(url, serviceKey, {
    global: { fetch: timedFetch(RPC_TIMEOUT_MS) },
  });
  const anon = createClient(url, anonKey, {
    global: { fetch: timedFetch(GOTRUE_TIMEOUT_MS) },
  });

  const key = identifierKey(identifier);
  const ip = callerIp(req);

  try {
    // Reserve the attempt atomically; NULL means locked out. Nothing
    // else happens before this point.
    const { data: attemptId, error: beginError } = await service.rpc(
      "auth_login_begin",
      { p_identifier_key: key, p_ip: ip },
    );
    if (beginError) {
      console.error("auth-login begin error", beginError.code ?? "unknown");
      return json(UNAVAILABLE, 503);
    }
    if (typeof attemptId !== "number") {
      return json({ error: "too_many_attempts" }, 429);
    }

    // finish() MUST be awaited and inspected on every path: if the
    // accounting cannot be recorded, the request fails closed with 503
    // and no tokens are issued.
    const finish = async (success: boolean): Promise<boolean> => {
      const { data: recorded, error: finishError } = await service.rpc(
        "auth_login_finish",
        { p_attempt_id: attemptId, p_success: success },
      );
      if (finishError || recorded !== true) {
        console.error(
          "auth-login finish error",
          finishError?.code ?? "row-mismatch",
        );
        return false;
      }
      return true;
    };

    // Padded credential failure: unknown identifier and wrong password
    // are indistinguishable in status, body and approximate timing.
    const failCredentials = async (): Promise<Response> => {
      if (!(await finish(false))) return json(UNAVAILABLE, 503);
      const elapsed = Date.now() - started;
      // Floor is MIN + jitter: jitter only ever widens the pad.
      const target = MIN_RESPONSE_MS + Math.floor(Math.random() * 100);
      if (elapsed < target) await sleep(target - elapsed);
      return json(INVALID, 401);
    };

    const { data: email, error: resolveError } = await service.rpc(
      "auth_login_resolve_email",
      { p_identifier: identifier },
    );
    if (resolveError) {
      console.error("auth-login resolve error", resolveError.code ?? "unknown");
      await finish(false);
      return json(UNAVAILABLE, 503);
    }

    // Unknown identifier: the real call is replaced by a dummy GoTrue
    // password check against a deterministic address that can never
    // exist, so timing matches the known-identifier path. The dummy
    // result only steers availability handling - it can never issue
    // tokens.
    const resolved = typeof email === "string" && email !== "";
    const targetEmail = resolved
      ? email
      : `missing-${await sha256Hex(key)}@login.invalid`;
    const knownAccount = resolved;

    const outcome = await trySignIn(anon, targetEmail, password);

    if (outcome.kind === "unavailable") {
      await finish(false);
      return json(UNAVAILABLE, 503);
    }
    if (outcome.kind === "credential" || !knownAccount) {
      return await failCredentials();
    }

    // Deny tokens unless the success was durably recorded.
    if (!(await finish(true))) return json(UNAVAILABLE, 503);

    const s = outcome.session;
    // Session tokens only: no user object, no standalone email.
    return json({
      access_token: s.access_token,
      refresh_token: s.refresh_token,
      expires_in: s.expires_in,
      token_type: s.token_type,
    }, 200);
  } catch (e) {
    // Timeouts and unexpected throws: controlled 503, nothing else.
    console.error("auth-login error", e instanceof Error ? e.name : "unknown");
    return json(UNAVAILABLE, 503);
  }
});
