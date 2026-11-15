import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

function storagePath(value: unknown, bucket: string): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const normalized = value.trim();
  const marker = "/" + bucket + "/";
  const index = normalized.indexOf(marker);

  if (index >= 0) {
    const raw = normalized.slice(index + marker.length).split("?")[0];
    try {
      return decodeURIComponent(raw).replace(/^\/+/, "");
    } catch {
      throw new Error("A stored media URL is malformed; no account data was deleted.");
    }
  }

  // Chat and wall attachments are stored as bucket-relative object paths.
  if (!/^https?:\/\//i.test(normalized)) {
    return normalized.replace(/^\/+/, "");
  }

  throw new Error("A stored media URL does not match its expected bucket; no account data was deleted.");
}

function uniquePaths(values: unknown[], bucket: string): string[] {
  return [...new Set(values.map((value) => storagePath(value, bucket)).filter((value): value is string => Boolean(value)))];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    if (!token) return json({ error: "Authentication required" }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const publishableKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
    const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
    const anonKey = publishableKeys
      ? JSON.parse(publishableKeys).default
      : Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = secretKeys
      ? JSON.parse(secretKeys).default
      : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !anonKey || !serviceKey) {
      return json({ error: "Server authentication keys are unavailable" }, 503);
    }

    const authClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

    const caller = authData.user;
    const body = await req.json().catch(() => ({}));
    const targetUserId =
      typeof body.targetUserId === "string" && body.targetUserId.trim()
        ? body.targetUserId.trim()
        : caller.id;
    const isSelf = targetUserId === caller.id;
    const convertToOwner = body.convertToOwner === true;

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: isOwner, error: ownerError } = await admin.rpc(
      "is_mk_owner_for_user",
      { p_user_id: caller.id },
    );
    if (ownerError) return json({ error: "Could not verify Owner permissions" }, 503);

    if (convertToOwner) {
      if (!isSelf || (caller.email || "").toLowerCase() !== "1987zinwaimin@gmail.com") {
        return json({ error: "Only the designated account can complete first Owner setup" }, 403);
      }
      const { data: canBootstrap, error: ownerCountError } = await admin.rpc(
        "can_bootstrap_mk_owner",
        { p_user_id: caller.id },
      );
      if (ownerCountError) return json({ error: "Could not verify initial Owner setup state" }, 503);
      if (canBootstrap !== true) return json({ error: "Owner setup is unavailable or has already been completed" }, 409);
      if (isOwner === true) return json({ error: "This account is already an Owner" }, 409);
    } else {
      if (!isSelf && isOwner !== true) {
        return json({ error: "Owner permission required to delete another account" }, 403);
      }
      if (isSelf && isOwner === true) {
        return json({ error: "Owner account cannot be deleted through Customer Account deletion" }, 403);
      }
    }

    const { data: target, error: targetError } = await admin.auth.admin.getUserById(targetUserId);
    if (targetError || !target.user) return json({ error: "Customer account does not exist" }, 404);

    // Preflight every referenced object before deleting relational metadata.
    const { data: paths, error: pathsError } = await admin.rpc(
      "get_mk_customer_storage_paths",
      { p_user_id: targetUserId },
    );
    if (pathsError) {
      console.error("Customer storage preflight failed:", pathsError.message);
      return json({ error: "Could not verify all customer media. No account data was deleted." }, 500);
    }

    let chatPaths: string[];
    let wallPaths: string[];
    let avatarPaths: string[];
    try {
      chatPaths = uniquePaths(paths?.chat_paths || [], "chat-media");
      wallPaths = uniquePaths(paths?.wall_paths || [], "wall-media");
      const avatar = storagePath(paths?.avatar_path, "profile-avatars");
      avatarPaths = avatar ? [avatar] : [];
    } catch (error) {
      return json({ error: error instanceof Error ? error.message : "Invalid media path" }, 500);
    }

    const cleanupFailures: string[] = [];
    const buckets = [
      ["chat-media", chatPaths],
      ["wall-media", wallPaths],
      ["profile-avatars", avatarPaths],
    ] as const;

    for (const [bucket, objectPaths] of buckets) {
      for (let offset = 0; offset < objectPaths.length; offset += 100) {
        const batch = objectPaths.slice(offset, offset + 100);
        const { error } = await admin.storage.from(bucket).remove(batch);
        if (error) cleanupFailures.push(bucket + ": " + error.message);
      }
    }

    // Fail closed: keep both DB metadata and Auth account if any storage removal failed.
    if (cleanupFailures.length) {
      console.error("Customer storage cleanup failed:", cleanupFailures);
      return json({
        error: "Some customer media could not be removed. Database and Auth deletion were stopped; retry after resolving Storage permissions.",
        storageCleanupWarnings: cleanupFailures,
      }, 500);
    }

    const { error: purgeError } = await admin.rpc("purge_mk_customer_data", {
      p_user_id: targetUserId,
    });
    if (purgeError) {
      console.error("Customer relational purge failed:", purgeError.message);
      return json({
        error: "Media cleanup completed, but database cleanup failed. The Auth account was retained; retry the deletion or contact the administrator.",
      }, 500);
    }

    if (convertToOwner) {
      const username = typeof body.username === "string" && /^[a-zA-Z0-9_]{3,24}$/.test(body.username)
        ? body.username
        : "zinwaimin";
      const displayName = typeof body.displayName === "string" && body.displayName.trim()
        ? body.displayName.trim().slice(0, 80)
        : "MK Owner";
      const { error: ownerSetupError } = await admin.rpc("bootstrap_mk_owner", {
        p_user_id: targetUserId,
        p_username: username,
        p_display_name: displayName,
      });
      if (ownerSetupError) {
        console.error("First Owner setup failed after customer data purge:", ownerSetupError.message);
        return json({
          error: "Customer data cleanup completed, but Owner setup failed. The login account was retained; contact the administrator.",
        }, 500);
      }
      return json({
        ok: true,
        convertedToOwner: true,
        ownerEmail: "1987zinwaimin@gmail.com",
        storageCleanupWarnings: [],
      });
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(targetUserId);
    if (deleteError) {
      console.error("Auth user deletion failed after data purge:", deleteError.message);
      return json({
        error: "Customer data was removed, but Auth account deletion failed. The Auth account was retained; contact the administrator.",
      }, 500);
    }

    return json({
      ok: true,
      deletedUserId: targetUserId,
      storageCleanupWarnings: [],
    });
  } catch (error) {
    console.error("delete-customer-account error:", error);
    return json({
      error: error instanceof Error
        ? error.message
        : "Account deletion failed. Please try again or contact support.",
    }, 500);
  }
});
