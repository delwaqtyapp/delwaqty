import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const FCM_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function b64url(data: Uint8Array): string {
  let bin = "";
  for (const byte of data) bin += String.fromCharCode(byte);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function rs256Sign(
  privateKeyPkcs8: string,
  header: string,
  payload: string,
): Promise<string> {
  const pemBody = privateKeyPkcs8
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const data = new TextEncoder().encode(`${header}.${payload}`);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, data);
  return b64url(new Uint8Array(sig));
}

async function getAccessToken(serviceAccount: string): Promise<string> {
  const account = JSON.parse(serviceAccount);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(new TextEncoder().encode(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  ));
  const claims = b64url(new TextEncoder().encode(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: FCM_TOKEN_URL,
      iat: now,
      exp: now + 3600,
    }),
  ));
  const signature = await rs256Sign(account.private_key, header, claims);
  const jwt = `${header}.${claims}.${signature}`;

  const res = await fetch(FCM_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`oauth_error ${res.status}: ${body.slice(0, 500)}`);
  }
  const token = await res.json();
  return token.access_token as string;
}

async function markStatus(
  supabase: ReturnType<typeof createClient>,
  notificationId: string,
  status: string,
  error?: string,
): Promise<void> {
  const patch: Record<string, string | null> = {
    push_status: status,
    push_sent_at: status === "sent" ? new Date().toISOString() : null,
  };
  if (error !== undefined) patch.push_error = error;
  await supabase
    .from("notifications")
    .update(patch)
    .eq("id", notificationId);
}

async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return json({ ok: true });

  const expectedToken = Deno.env.get("SEND_PUSH_TOKEN");
  if (!expectedToken) {
    return json({ error: "unconfigured_send_token" }, 401);
  }
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${expectedToken}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const payload = await req.json().catch(() => null);
  const notificationId = payload?.notification_id;
  if (typeof notificationId !== "string") {
    return json({ error: "missing_notification_id" }, 400);
  }

  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    return json({ error: "server_misconfigured" }, 500);
  }
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  if (!serviceAccountJson) {
    await markStatus(supabase, notificationId, "unconfigured");
    return json({ ok: true, status: "unconfigured" });
  }

  const { data: notification, error: notifError } = await supabase
    .from("notifications")
    .select("id, user_id, title, body, data")
    .eq("id", notificationId)
    .single();
  if (notifError || !notification || !notification.user_id) {
    return json({ ok: false, error: "notification_not_found" }, 404);
  }

  const { data: tokens } = await supabase
    .from("notification_tokens")
    .select("token, device_id")
    .eq("user_id", notification.user_id)
    .eq("is_active", true);

  if (!tokens || tokens.length === 0) {
    await markStatus(supabase, notificationId, "failed", "no_active_tokens");
    return json({ ok: true, status: "failed", reason: "no_active_tokens" });
  }

  const projectId = JSON.parse(serviceAccountJson).project_id;
  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccountJson);
  } catch (e) {
    const message = (e as Error).message;
    await markStatus(supabase, notificationId, "failed", message);
    return json({ ok: false, error: message }, 502);
  }

  const deepLink = typeof notification.data?.deep_link === "string"
    ? notification.data.deep_link as string
    : null;
  const payloadData: Record<string, string> = {
    type: typeof notification.data?.type === "string"
      ? notification.data.type as string
      : "info",
    notification_id: notificationId,
  };
  if (deepLink) payloadData.deep_link = deepLink;

  let failures = 0;
  for (const row of tokens) {
    const message = {
      message: {
        token: row.token,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: payloadData,
      },
    };
    const res = await fetch(`${FCM_SEND_URL}/${projectId}/messages:send`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });
    if (res.ok) continue;
    failures += 1;
    const status = res.status;
    const body = await res.text();
    if (status === 404 || status === 410) {
      await supabase.rpc("cleanup_invalid_token", { p_token: row.token });
    }
    if (failures === 1) {
      await markStatus(supabase, notificationId, "failed", `fcm_${status}:${body.slice(0, 300)}`);
    }
  }

  if (failures === 0) {
    await markStatus(supabase, notificationId, "sent");
    return json({ ok: true, status: "sent", devices: tokens.length });
  }
  return json({ ok: true, status: "failed", failures });
}

Deno.serve(async (req: Request) => {
  try {
    return await handleRequest(req);
  } catch (e) {
    return json({ error: "internal_error", detail: (e as Error).message }, 500);
  }
});
