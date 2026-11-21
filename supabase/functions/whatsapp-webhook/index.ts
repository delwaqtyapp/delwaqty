// whatsapp-webhook: inbound WhatsApp Cloud API receiver (design H3).
//
// Closes the OTP loop: request_whatsapp_otp generates the code, the user
// sends it from their own WhatsApp to the platform number, and THIS webhook
// is the only path allowed to mark it verified. The app then confirms via
// the verify_whatsapp_otp(phone, code) RPC the user types, or polls the
// verification status. See docs/whatsapp-otp-inbound.md.
//
// Secrets (supabase secrets set, never in repo):
//   WHATSAPP_VERIFY_TOKEN  - random string we choose, entered in Meta's
//                            webhook config for the GET handshake.
//   WHATSAPP_APP_SECRET    - Meta app secret, signs X-Hub-Signature-256.
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided by the runtime.
//
// Deploy: supabase functions deploy whatsapp-webhook --no-verify-jwt
// (--no-verify-jwt: Meta cannot present a user JWT; the HMAC signature is
// the authentication mechanism instead.)

import { createClient } from "npm:@supabase/supabase-js@2.39.0";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function hmacSha256Hex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

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

Deno.serve(async (req) => {
  const verifyToken = Deno.env.get("WHATSAPP_VERIFY_TOKEN") ?? "";
  const appSecret = Deno.env.get("WHATSAPP_APP_SECRET") ?? "";

  // Meta webhook handshake.
  if (req.method === "GET") {
    const url = new URL(req.url);
    if (
      url.searchParams.get("hub.mode") === "subscribe" &&
      verifyToken !== "" &&
      url.searchParams.get("hub.verify_token") === verifyToken
    ) {
      return new Response(url.searchParams.get("hub.challenge") ?? "", {
        status: 200,
      });
    }
    return json({ error: "forbidden" }, 403);
  }

  if (req.method !== "POST") return json({ error: "method" }, 405);

  const body = await req.text();

  // Every delivery must carry a valid app-secret signature.
  const header = req.headers.get("x-hub-signature-256") ?? "";
  const expected = `sha256=${await hmacSha256Hex(appSecret, body)}`;
  if (appSecret === "" || header !== expected) {
    return json({ error: "bad signature" }, 401);
  }

  let payload: any;
  try {
    payload = JSON.parse(body);
  } catch {
    return json({ error: "bad json" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const results: unknown[] = [];
  const entries = payload?.entry ?? [];
  for (const entry of entries) {
    for (const change of entry?.changes ?? []) {
      const messages = change?.value?.messages ?? [];
      for (const msg of messages) {
        // Idempotency: Meta retries deliveries; never process twice.
        const messageId = msg?.id as string | undefined;
        const from = normalizeEgyptPhone(String(msg?.from ?? ""));
        const text = String(msg?.text?.body ?? "");
        const code = (text.match(/\b(\d{6})\b/) ?? [])[1];
        if (!messageId || !code) continue;

        const { data, error } = await supabase.rpc(
          "whatsapp_webhook_mark_verified",
          {
            p_phone: from,
            p_otp_code: code,
            p_message_id: messageId,
          },
        );
        results.push({ messageId, from, ok: !error && data === true });
      }
    }
  }

  // Always 200 after signature validation: non-200 makes Meta retry forever.
  return json({ received: true, results });
});
