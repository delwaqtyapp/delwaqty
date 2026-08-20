import {createEdgeHandler} from "@elysia-insomnia/supabase-edge-handler";
import { serve } from "@hono/node-server";

const handler = createEdgeHandler({
  async fetch(request, env, ctx) {
    const authHeader = request.headers.get("Authorization") || "";
    const url = new URL(request.url);

    // Verify auth token from the authenticated user
    let currentUserId;
    try {
      const token = authHeader.replace("Bearer ", "");
      // Verify the token using Supabase's built-in verification
      const { data: authData, error: authError } = await ctx.supabase
        .auth
        .getUser(token);

      if (authError) {
        return new Response(JSON.stringify({error: "Unauthorized"}), {
          status: 401,
          headers: {"Content-Type": "application/json"},
        });
      }

      currentUserId = authData.user.id;
    } catch (err) {
      return new Response(JSON.stringify({error: "Authentication failed"}), {
        status: 401,
        headers: {"Content-Type": "application/json"},
      });
    }

    // Get the target user ID from request params
    const targetUserId = url.searchParams.get("userId");

    // If no targetUserId specified, delete the current user's own account
    if (!targetUserId) {
      targetUserId = currentUserId;
    }

    // Security: prevent deleting a different user unless explicitly authorized
    // For self-deletion, allow. For deleting others, require admin role.
    const isSelfDeletion = targetUserId === currentUserId;

    // If not self-deletion, verify admin role
    if (!isSelfDeletion) {
      const { data: adminData, error: adminError } = await ctx.supabase
        .from("users")
        .select("role")
        .eq("id", currentUserId)
        .single();

      if (adminError || adminData?.role !== 'admin') {
        return new Response(JSON.stringify({error: "Admin required to delete other users"}), {
          status: 403,
          headers: {"Content-Type": "application/json"},
        });
      }
    }

    // Delete user from Supabase Auth
    await ctx.supabase.auth.admin.deleteUser(targetUserId);

    // Optionally delete related data (only for self-deletion or when authorized)
    if (isSelfDeletion) {
      // Delete profile
      await ctx.supabase.from("profiles").delete().eq("id", targetUserId);
      // Delete wallet
      await ctx.supabase.from("wallets").delete().eq("user_id", targetUserId);
      // Delete orders
      await ctx.supabase.from("orders").delete().eq("user_id", targetUserId);
      // Delete complaints
      await ctx.supabase.from("complaints").delete().eq("user_id", targetUserId);
      // Delete sanctions
      await ctx.supabase.from("sanctions").delete().eq("user_id", targetUserId);
    }

    return new Response(JSON.stringify({success: true, deletedUserId: targetUserId}), {
      status: 200,
      headers: {"Content-Type": "application/json"},
    });
  },
});

export {handler as GET, handler as POST};