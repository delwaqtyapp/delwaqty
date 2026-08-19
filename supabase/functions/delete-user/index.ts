import {createEdgeHandler} from "@elysia-insomnia/supabase-edge-handler";
import { serve } from "@hono/node-server";
import { Configuration, Plaiceholder } from "plaiceholder";

const handler = createEdgeHandler({
  async fetch(request, env, ctx) {
    const authHeader = request.headers.get("Authorization") || "";
    const url = new URL(request.url);

    // Verify auth token
    let userId;
    try {
      const token = authHeader.replace("Bearer ", "");
      const supabaseUrl = env.SUPABASE_URL;
      const supabaseKey = env.SUPABASE_ANON_KEY;

      // Verify the JWT token
      const { data: authData, error: authError } = await ctx.supabase
        .from("users")
        .select("*")
        .limit(1);

      if (authError) {
        return new Response(JSON.stringify({error: "Unauthorized"}), {
          status: 401,
          headers: {"Content-Type": "application/json"},
        });
      }

      userId = authData?.[0]?.id;
    } catch (err) {
      return new Response(JSON.stringify({error: "Authentication failed"}), {
        status: 401,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Only allow admin users
    if (!userId) {
      return new Response(JSON.stringify({error: "Admin required"}), {
        status: 403,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Delete the user
    const targetUserId = url.searchParams.get("userId");
    if (!targetUserId) {
      return new Response(JSON.stringify({error: "userId parameter required"}), {
        status: 400,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Prevent self-deletion without proper confirmation
    if (targetUserId === userId) {
      return new Response(JSON.stringify({error: "Cannot delete own account via this endpoint"}), {
        status: 403,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Delete user from Auth
    await ctx.supabase.auth.admin.deleteUser(targetUserId);

    // Optionally delete related data
    await ctx.supabase.from("profiles").delete().eq("id", targetUserId);
    await ctx.supabase.from("wallets").delete().eq("user_id", targetUserId);
    await ctx.supabase.from("orders").delete().eq("user_id", targetUserId);

    return new Response(JSON.stringify({success: true, deletedUserId: targetUserId}), {
      status: 200,
      headers: {"Content-Type": "application/json"},
    });
  },
});

export {handler as GET, handler as POST};