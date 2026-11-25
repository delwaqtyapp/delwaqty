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
//   WHATSAPP_CLOUD_TOKEN   - Cloud API access token (sending replies).
//   WHATSAPP_PHONE_NUMBER_ID - Cloud API phone number id of the OTP number.
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided by the runtime.
//   Replies are best-effort: missing secrets or a send failure never break
//   verification, and a user reply is free inside the 24h customer window
//   that their own code message just opened (no template needed).
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

// Constant-time string compare: a naive !== leaks how many leading
// characters matched through response timing, which chips away at the
// signature (and the verify token) guess by guess.
function timingSafeEqual(a: string, b: string): boolean {
  const ba = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  let diff = ba.length ^ bb.length;
  const len = Math.max(ba.length, bb.length);
  for (let i = 0; i < len; i++) {
    diff |= (ba[i % Math.max(ba.length, 1)] ?? 0) ^ (bb[i % Math.max(bb.length, 1)] ?? 0);
  }
  return diff === 0;
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

// Replies sent from the platform number. Confirmation reflects the actual
// state at this point: the phone number is verified; signup completes in
// the app afterwards.
const CONFIRMATION_BODY = "تم التحقق من رقمك ✅ ارجع للتطبيق";
const INVALID_CODE_BODY =
  "الكود غير صالح أو انتهت صلاحيته. اطلب كودًا جديدًا من التطبيق.";

// Guidance is offered only for a phone with a currently pending code:
// unverified, created within the last 30 minutes, not locked. Any other
// message is ignored.
const GUIDANCE_WINDOW_MS = 30 * 60 * 1000;

// A hung Graph request must not stall the webhook ack.
const REPLY_TIMEOUT_MS = 3000;

// Best-effort Cloud API text reply. Never throws: verification must not
// depend on Meta accepting our reply. Logs only the error class or status,
// never headers or exception bodies.
async function sendWhatsAppText(toDigits: string, bodyText: string): Promise<void> {
  const token = Deno.env.get("WHATSAPP_CLOUD_TOKEN") ?? "";
  const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ?? "";
  if (token === "" || phoneNumberId === "") return; // not wired yet
  try {
    const resp = await fetch(
      `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: toDigits,
          type: "text",
          text: { body: bodyText },
        }),
        signal: AbortSignal.timeout(REPLY_TIMEOUT_MS),
      },
    );
    if (!resp.ok) {
      console.error("whatsapp reply failed with status", resp.status);
    }
  } catch (e) {
    console.error("whatsapp reply error", e instanceof Error ? e.name : "unknown");
  }
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
      timingSafeEqual(url.searchParams.get("hub.verify_token") ?? "", verifyToken)
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
  if (appSecret === "" || !timingSafeEqual(header, expected)) {
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
        const ok = !error && data === true;
        results.push({ messageId, from, ok });

        const toDigits = from.replace(/^\+/, "");
        if (ok) {
          // Phone verified: tell the user they can go back to the app. Only
          // one delivery can win the verified=false UPDATE inside the RPC,
          // so this fires exactly once per code.
          await sendWhatsAppText(toDigits, CONFIRMATION_BODY);
        } else if (!error) {
          // Wrong or expired code. Reply only when this phone has a
          // currently pending OTP: never answer random chats on a shared
          // number, never on an RPC error.
          const nowIso = new Date().toISOString();
          const { data: otpRows } = await supabase
            .from("whatsapp_otp_verifications")
            .select("id")
            .eq("phone", from)
            .eq("verified", false)
            .gt("created_at", new Date(Date.now() - GUIDANCE_WINDOW_MS).toISOString())
            .or(`locked_until.is.null,locked_until.lt.${nowIso}`)
            .limit(1);
          if (otpRows && otpRows.length > 0) {
            // Atomically claim this delivery id before replying: a Meta
            // retry or a concurrent duplicate of the same message conflicts
            // on unique(message_id) and sends nothing. The row the RPC
            // wrote for a successful verify conflicts the same way, so a
            // duplicate that lost the verify race can never nudge after a
            // confirmation.
            const { data: claim } = await supabase
              .from("whatsapp_webhook_messages")
              .insert(
                { message_id: messageId, phone: from },
                { onConflict: "message_id", ignoreDuplicates: true },
              )
              .select("message_id");
            if (claim && claim.length > 0) {
              await sendWhatsAppText(toDigits, INVALID_CODE_BODY);
            }
          }
        }
      }
    }
  }

  // Always 200 after signature validation: non-200 makes Meta retry forever.
  return json({ received: true, results });
});
