/// <reference lib="deno.ns" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { userId } = await req.json();
    if (!userId) return new Response("Missing userId", { status: 400 });

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // 1) delete profile first (optional)
    const { error: profileErr } = await admin.from("profiles").delete().eq("user_id", userId);

    // 2) delete auth user (this is the real deletion)
    const { error: authErr } = await admin.auth.admin.deleteUser(userId);
    if (authErr) {
      return new Response(`Auth delete error: ${authErr.message}`, { status: 500 });
    }

    // If profile deletion failed, return warning but still ok
    if (profileErr) {
      return new Response(`Deleted auth user, but profile delete error: ${profileErr.message}`, { status: 200 });
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    return new Response(`Error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
});
