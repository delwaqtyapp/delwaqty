import { createClient } from "npm:@supabase/supabase-js@2.39.0";

// delete-user: self-service account deletion (customer app "Delete Account").
//
// Orchestrates a full, verifiable deletion:
//   1. Authenticate the caller from their JWT (401 unless valid).
//   2. Purge the member's storage objects through the Storage API (direct
//      deletes on storage.objects are blocked at the DB level).
//   3. Call public.delete_user_data (service-role only, one transaction):
//      purges personal rows, anonymizes the account via the moderation
//      engine, removes the auth row.
// Every step is checked; any failure returns a 5xx with the failing step
// and nothing reports success unless deletion actually completed.

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

// Buckets whose objects are prefixed by the bare user id.
const USER_PREFIX_BUCKETS = [
  "service-audio-logs",
  "topup-proofs",
  "identity-documents",
  "driver-documents",
  "profile-photos",
];

async function removePrefix(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<number> {
  let removed = 0;
  for (;;) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 1000,
    });
    if (error) throw new Error(`storage list ${bucket}/${prefix}: ${error.message}`);
    if (!data || data.length === 0) return removed;
    const paths = data
      .filter((o) => o.id !== null && o.name !== ".emptyFolderPlaceholder")
      .map((o) => `${prefix}${o.name}`);
    for (const folder of data.filter((o) => o.id === null)) {
      removed += await removePrefix(admin, bucket, `${prefix}${folder.name}/`);
    }
    if (paths.length === 0) return removed;
    const { error: rmError } = await admin.storage.from(bucket).remove(paths);
    if (rmError) throw new Error(`storage remove ${bucket}/${prefix}: ${rmError.message}`);
    removed += paths.length;
    if (data.length < 1000) return removed;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    if (!token) return json({ error: "Unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1. Authenticate the caller.
    const userClient = createClient(supabaseUrl, anonKey);
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "Unauthorized" }, 401);
    const callerId = authData.user.id;

    const admin = createClient(supabaseUrl, serviceKey);

    // Deleting someone else requires an admin caller.
    const url = new URL(req.url);
    const targetId = url.searchParams.get("userId") ?? callerId;
    if (targetId !== callerId) {
      const { data: callerRow, error: roleError } = await admin
        .from("users")
        .select("role")
        .eq("id", callerId)
        .single();
      if (roleError || callerRow?.role !== "admin") {
        return json({ error: "Admin required to delete other users" }, 403);
      }
    }

    // 2. Purge storage objects through the Storage API.
    let storageRemoved = 0;
    const { data: rooms, error: roomsError } = await admin
      .from("chat_rooms")
      .select("id")
      .contains("participant_ids", [targetId]);
    if (roomsError) throw new Error(`chat_rooms lookup: ${roomsError.message}`);
    for (const room of rooms ?? []) {
      storageRemoved += await removePrefix(admin, "chat_attachments", `${room.id}/`);
    }
    for (const bucket of USER_PREFIX_BUCKETS) {
      storageRemoved += await removePrefix(admin, bucket, `${targetId}/`);
    }
    storageRemoved += await removePrefix(admin, "profiles", `avatars/${targetId}/`);

    // 3. Transactional row purge + anonymize + auth delete (single RPC).
    const { error: rpcError } = await admin.rpc("delete_user_data", {
      p_uid: targetId,
      p_reason: "user_requested",
    });
    if (rpcError) throw new Error(`delete_user_data: ${rpcError.message}`);

    return json({ success: true, deletedUserId: targetId, storageRemoved });
  } catch (err) {
    return json({ error: String(err instanceof Error ? err.message : err) }, 500);
  }
});
