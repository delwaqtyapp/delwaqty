import {createEdgeHandler} from "@elysia-insomnia/supabase-edge-handler";
import { serve } from "@hono/node-server";

// Secure Admin Creation boundary.
//
// Security model:
//   - The Flutter client NEVER holds the service_role key. It only sends the
//     caller's JWT. All privileged operations happen here, server-side.
//   - Authorization is re-checked here (caller must be an active admin/owner)
//     before any privileged Auth Admin API call.
//   - New Auth identity is created via the Admin API, then promoted through the
//     existing, audited lifecycle executor `_admin_exec_create` (which enforces
//     the full supervision / region / escalation invariant set).
const handler = createEdgeHandler({
  async fetch(request, env, ctx) {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({error: "Method not allowed"}), {
        status: 405,
        headers: {"Content-Type": "application/json"},
      });
    }

    const authHeader = request.headers.get("Authorization") || "";
    let callerId: string | undefined;
    try {
      const token = authHeader.replace("Bearer ", "");
      const { data: authData, error: authError } = await ctx.supabase
        .auth
        .getUser(token);
      if (authError || !authData?.user?.id) {
        return new Response(JSON.stringify({error: "Unauthorized"}), {
          status: 401,
          headers: {"Content-Type": "application/json"},
        });
      }
      callerId = authData.user.id;
    } catch {
      return new Response(JSON.stringify({error: "Authentication failed"}), {
        status: 401,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Authorize: caller must be an active admin or the owner.
    const { data: authz, error: authzErr } = await ctx.supabase.rpc(
      "is_active_admin_uid",
      { p_uid: callerId },
    );
    if (authzErr || !authz) {
      return new Response(
        JSON.stringify({error: "Admin privileges required to create admins"}),
        {status: 403, headers: {"Content-Type": "application/json"}},
      );
    }

    let body: any;
    try {
      body = await request.json();
    } catch {
      return new Response(JSON.stringify({error: "Invalid JSON body"}), {
        status: 400,
        headers: {"Content-Type": "application/json"},
      });
    }

    const email = (body?.email as string | undefined)?.trim().toLowerCase();
    const password = body?.password as string | undefined;
    const fullName = (body?.full_name as string | undefined)?.trim();
    const supervisorId = body?.supervisor_id as string | undefined;
    const regionId = body?.region_id as string | undefined;
    const scope = (body?.scope as string | undefined) || "descendants";

    if (!email || !password || !fullName) {
      return new Response(
        JSON.stringify({error: "email, password and full_name are required"}),
        {status: 400, headers: {"Content-Type": "application/json"}},
      );
    }
    if (password.length < 8) {
      return new Response(
        JSON.stringify({error: "password must be at least 8 characters"}),
        {status: 400, headers: {"Content-Type": "application/json"}},
      );
    }

    // 1) Create the Auth identity (privileged Admin API, server-side only).
    const { data: newUser, error: createErr } = await ctx.supabase.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {full_name: fullName},
      });
    if (createErr || !newUser?.user?.id) {
      return new Response(
        JSON.stringify({error: createErr?.message || "Failed to create user"}),
        {status: 400, headers: {"Content-Type": "application/json"}},
      );
    }
    const newUserId = newUser.user.id;

    // 2) Promote through the audited lifecycle executor (enforces invariants).
    try {
      await ctx.supabase.rpc("_admin_exec_create", {
        p_actor: callerId,
        p_user_id: newUserId,
        p_supervisor_id: supervisorId ?? null,
        p_region_id: regionId ?? null,
        p_scope: scope,
      });
    } catch (e: any) {
      // Roll back the Auth identity if promotion failed.
      await ctx.supabase.auth.admin.deleteUser(newUserId).catch(() => {});
      return new Response(
        JSON.stringify({error: e?.message || "Failed to promote admin"}),
        {status: 400, headers: {"Content-Type": "application/json"}},
      );
    }

    return new Response(
      JSON.stringify({success: true, adminId: newUserId, email}),
      {status: 200, headers: {"Content-Type": "application/json"}},
    );
  },
});

export {handler as GET, handler as POST};
