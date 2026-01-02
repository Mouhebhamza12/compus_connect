/// <reference lib="deno.ns" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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

  try {
    const { email, name, status } = await req.json();

    if (!email || !status) {
      return new Response("Missing email or status", { status: 400, headers: corsHeaders });
    }

    if (status !== "approved" && status !== "rejected") {
      return new Response("Invalid status", { status: 400, headers: corsHeaders });
    }

    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "onboarding@resend.dev";
    const FROM_NAME = Deno.env.get("FROM_NAME") ?? "Campus Connect";
    const SUPPORT_EMAIL = "compusconnectsupport@gmail.com";

    if (!RESEND_API_KEY) {
      return new Response("Missing RESEND_API_KEY", { status: 500, headers: corsHeaders });
    }

    const subject =
      status === "approved"
        ? "Campus Connect Account Approved"
        : "Update on Your Campus Connect Account Request";

    const html =
      status === "approved"
        ? `
          <div style="font-family: Arial, sans-serif; font-size: 15px; color: #111; line-height: 1.6;">
            <p>Hi ${name || "there"},</p>

            <p>
              Your request to join <b>Campus Connect</b> has been approved. Your account is now active,
              and you can log in using the email address you registered with.
            </p>

            <p>
              <b>Next steps:</b><br/>
              • Log in to your account<br/>
              • Complete your profile if needed<br/>
              • Start using the platform and accessing available features
            </p>

            <p>
              If you have any questions or experience any issues, please contact our support team at
              <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.
            </p>

            <p style="margin-top: 24px;">
              Regards,<br/>
              <b>The Campus Connect Team</b>
            </p>
          </div>
        `
        : `
          <div style="font-family: Arial, sans-serif; font-size: 15px; color: #111; line-height: 1.6;">
            <p>Hi ${name || "there"},</p>

            <p>
              Thank you for your interest in joining <b>Campus Connect</b>.
              After reviewing your request, we are unable to approve your account at this time.
            </p>

            <p>
              This may be due to missing information, eligibility requirements, or verification issues.
              If you believe this decision was made in error, you can contact our support team for clarification.
            </p>

            <p>
              Support: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>
            </p>

            <p style="margin-top: 24px;">
              Regards,<br/>
              <b>The Campus Connect Team</b>
            </p>
          </div>
        `;

    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        to: [email],
        subject,
        html,
      }),
    });

    const text = await resp.text();

    if (!resp.ok) {
      console.error("Resend error", resp.status, text);
      return new Response(`Resend error: ${resp.status} ${text}`, {
        status: 500,
        headers: corsHeaders,
      });
    }

    return new Response("ok", { status: 200, headers: corsHeaders });
  } catch (e) {
    console.error("Unexpected error", e);
    return new Response(`Error: ${e instanceof Error ? e.message : String(e)}`, {
      status: 500,
      headers: corsHeaders,
    });
  }
});
