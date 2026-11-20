import { createClient } from "npm:@supabase/supabase-js@2.39.0";

// create-admin: secure admin creation boundary.
//
// Security model:
//   - The Flutter client NEVER holds the service_role key. It only sends the
//     caller's JWT. All privileged operations happen here, server-side.
//   - Authorization is re-checked here (caller must be an active admin/owner)
//     before any privileged Auth Admin API call.
//   - New Auth identity is created via the Admin API, then promoted through
//     the existing, audited lifecycle executor `_admin_exec_create` (which
//     enforces the full supervision / region / escalation invariant set).
//   - If promotion fails, the Auth identity is rolled back.

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey);

  // Authenticate the caller from the forwarded JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  let callerId: string | undefined;
  try {
    const { data: authData, error: authError } = await admin.auth.getUser(
      token,
    );
    if (authError || !authData?.user?.id) {
      return json({ error: "Unauthorized" }, 401);
    }
    callerId = authData.user.id;
  } catch {
    return json({ error: "Authentication failed" }, 401);
  }

  // Authorize: caller must be an active admin or the owner.
  const { data: authz, error: authzErr } = await admin.rpc(
    "is_active_admin_uid",
    { p_uid: callerId },
  );
  if (authzErr || !authz) {
    return json(
      { error: "Admin privileges required to create admins" },
      403,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const email = (body?.email as string | undefined)?.trim().toLowerCase();
  const password = body?.password as string | undefined;
  const fullName = (body?.full_name as string | undefined)?.trim();
  const supervisorId = (body?.supervisor_id as string | undefined) ?? null;
  const regionId = (body?.region_id as string | undefined) ?? null;
  const scope = (body?.scope as string | undefined) || "descendants";

  if (!email || !password || !fullName) {
    return json(
      { error: "email, password and full_name are required" },
      400,
    );
  }
  if (password.length < 8) {
    return json({ error: "password must be at least 8 characters" }, 400);
  }

  // 1) Create the Auth identity (privileged Admin API, server-side only).
  const { data: newUser, error: createErr } = await admin.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
  if (createErr || !newUser?.user?.id) {
    return json(
      { error: createErr?.message || "Failed to create user" },
      400,
    );
  }
  const newUserId = newUser.user.id;

  // 2) Promote through the audited lifecycle executor (enforces invariants).
  const { error: promoteErr } = await admin.rpc("_admin_exec_create", {
    p_actor: callerId,
    p_user_id: newUserId,
    p_supervisor_id: supervisorId,
    p_region_id: regionId,
    p_scope: scope,
  });
  if (promoteErr) {
    // Roll back the Auth identity if promotion failed.
    await admin.auth.admin.deleteUser(newUserId).catch(() => {});
    return json(
      { error: promoteErr.message || "Failed to promote admin" },
      400,
    );
  }

  return json({ success: true, adminId: newUserId, email });
});
