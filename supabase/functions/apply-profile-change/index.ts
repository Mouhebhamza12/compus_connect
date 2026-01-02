import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return new Response("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization");
  const token = authHeader?.replace("Bearer", "").trim();
  if (!token) {
    return new Response("Missing authorization", { status: 401, headers: corsHeaders });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_e) {
    return new Response("Invalid JSON body", { status: 400, headers: corsHeaders });
  }

  const requestId = (body["requestId"] ?? "").toString();
  const action = (body["action"] ?? "").toString(); // "approve" | "reject"
  const note = (body["note"] ?? "").toString();

  if (!requestId || (action !== "approve" && action !== "reject")) {
    return new Response("Missing requestId or invalid action", { status: 400, headers: corsHeaders });
  }

  // Service role client (bypasses RLS)
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // Validate caller token and get user
  const { data: userData, error: userError } = await adminClient.auth.getUser(token);
  if (userError || !userData?.user) {
    return new Response("Invalid token", { status: 401, headers: corsHeaders });
  }

  const adminId = userData.user.id;

  // Check admin role
  const { data: adminProfile, error: adminProfileErr } = await adminClient
    .from("profiles")
    .select("role")
    .eq("user_id", adminId)
    .maybeSingle();

  if (adminProfileErr) {
    console.error("Admin profile fetch error", adminProfileErr);
    return new Response("Failed to verify admin", { status: 500, headers: corsHeaders });
  }

  if (adminProfile?.role !== "admin") {
    return new Response("Forbidden", { status: 403, headers: corsHeaders });
  }

  // Fetch request
  const { data: request, error: reqError } = await adminClient
    .from("profile_change_requests")
    .select("id, user_id, full_name, student_number, major, year, email, status")
    .eq("id", requestId)
    .maybeSingle();

  if (reqError || !request) {
    console.error("Request fetch error", reqError);
    return new Response("Request not found", { status: 404, headers: corsHeaders });
  }

  if (request.status !== "pending") {
    return new Response("Request already handled", { status: 409, headers: corsHeaders });
  }

  // Reject path
  if (action === "reject") {
    const { error: rejectError } = await adminClient
      .from("profile_change_requests")
      .update({
        status: "rejected",
        reviewed_at: new Date().toISOString(),
        reviewed_by: adminId,
        note: note || null,
      })
      .eq("id", requestId);

    if (rejectError) {
      console.error("Reject error", rejectError);
      return new Response("Failed to reject", { status: 500, headers: corsHeaders });
    }

    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  // Approve path: build updates
  const profileUpdate: Record<string, unknown> = {};
  if (request.full_name) profileUpdate.full_name = request.full_name;
  if (request.email) profileUpdate.email = request.email;

  const studentUpdate: Record<string, unknown> = {};
  if (request.student_number) studentUpdate.student_number = request.student_number;
  if (request.major !== undefined) studentUpdate.major = request.major ?? null;
  if (request.year !== undefined && request.year !== null) studentUpdate.year = request.year;

  // バ. FIX: profiles UPDATE first, then INSERT with role if row doesn't exist
  if (Object.keys(profileUpdate).length > 0) {
    const { data: updated, error: updErr } = await adminClient
      .from("profiles")
      .update(profileUpdate)
      .eq("user_id", request.user_id)
      .select("user_id");

    if (updErr) {
      console.error("Profile update error", updErr);
      return new Response("Failed to update profile", { status: 500, headers: corsHeaders });
    }

    if (!updated || updated.length === 0) {
      const { error: insErr } = await adminClient.from("profiles").insert({
        user_id: request.user_id,
        role: "student",      // REQUIRED because role is NOT NULL
        status: "active",
        ...profileUpdate,
      });

      if (insErr) {
        console.error("Profile insert error", insErr);
        return new Response("Failed to create profile", { status: 500, headers: corsHeaders });
      }
    }
  }

  // Update students (upsert is OK)
  if (Object.keys(studentUpdate).length > 0) {
    const { error } = await adminClient
      .from("students")
      .upsert({ user_id: request.user_id, ...studentUpdate }, { onConflict: "user_id" });

    if (error) {
      console.error("Student update error", error);
      return new Response("Failed to update student", { status: 500, headers: corsHeaders });
    }
  }

  // Update auth email (optional)
  if (request.email) {
    const { error: emailError } = await adminClient.auth.admin.updateUserById(request.user_id, {
      email: request.email,
    });

    if (emailError) {
      console.error("Email update error", emailError);
      return new Response("Failed to update auth email", { status: 500, headers: corsHeaders });
    }
  }

  // Mark request approved
  const { error: approveError } = await adminClient
    .from("profile_change_requests")
    .update({
      status: "approved",
      reviewed_at: new Date().toISOString(),
      reviewed_by: adminId,
      note: note || null,
    })
    .eq("id", requestId);

  if (approveError) {
    console.error("Approve error", approveError);
    return new Response("Failed to update request status", { status: 500, headers: corsHeaders });
  }

  return new Response("ok", { status: 200, headers: corsHeaders });
});

