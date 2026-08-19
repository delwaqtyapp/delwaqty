// delete_user.ts - Edge Function for account deletion
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return json({ ok: true });

  const expectedToken = Deno.env.get("DELETE_USER_TOKEN");
  if (!expectedToken) {
    return json({ error: "unconfigured_delete_token" }, 401);
  }
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${expectedToken}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    return json({ error: "server_misconfigured" }, 500);
  }
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  try {
    const userId = Deno.env.get("CURRENT_DELETION_USER_ID");
    if (!userId) {
      return json({ error: "missing_user_id" }, 400);
    }

    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, email, avatar_url, created_at, last_sign_in_at")
      .eq("id", userId)
      .single();
    if (userError || !user) {
      return json({ error: "user_not_found" }, 404);
    }

    const deletedBy = userId;
    const deletedAt = new Date().toISOString();

    await supabase.rpc("log_audit", {
      p_actor_id: deletedBy,
      p_action: "account_deletion_requested",
      p_target_type: "users",
      p_target_id: userId,
      p_metadata: {
        email: user.email,
        avatar_url: user.avatar_url,
        created_at: user.created_at,
        last_sign_in_at: user.last_sign_in_at,
      },
    });

    const { error: authDeleteError } = await supabase.auth.admin.deleteUser(userId);
    if (authDeleteError) {
      return json({ error: "auth_delete_failed", detail: authDeleteError.message }, 500);
    }

    const { error: userDeleteError } = await supabase
      .from("users")
      .delete()
      .eq("id", userId);
    if (userDeleteError) {
      return json({ error: "users_delete_failed", detail: userDeleteError.message }, 500);
    }

    await supabase.rpc("log_audit", {
      p_actor_id: deletedBy,
      p_action: "account_deletion_completed",
      p_target_type: "users",
      p_target_id: userId,
    });

    return json({
      ok: true,
      deleted_user_id: userId,
      deleted_at: deletedAt,
      deleted_email: user.email,
    });
  } catch (e) {
    return json({ error: "internal_error", detail: (e as Error).message }, 500);
  }
}

Deno.serve(async (req: Request) => {
  try {
    return await handleRequest(req);
  } catch (e) {
    return json({ error: "internal_error", detail: (e as Error).message }, 500);
  }
});
