// StockFlow — automatic broadcast email to all customers (Gmail SMTP, free).
//
// Deploy: Supabase Dashboard → Edge Functions → Create → name it
//   "send-broadcast-email" → paste this file → Deploy.
//
// Then set these secrets (Dashboard → Edge Functions → Secrets, or via CLI):
//   GMAIL_USER          your full gmail address (e.g. stockflow.navy@gmail.com)
//   GMAIL_APP_PASSWORD  16-char Google App Password
//                       (Google Account → Security → 2-Step Verification → App passwords)
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { subject, body } = await req.json();

    // Service-role client — reads customer emails server-side (bypasses RLS).
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: customers, error } = await supabase
      .from("profiles")
      .select("email")
      .eq("role", "customer");
    if (error) throw error;

    const emails = (customers ?? [])
      .map((c: { email: string | null }) => (c.email ?? "").trim())
      .filter((e: string) => e.includes("@"));

    if (emails.length === 0) {
      return new Response(JSON.stringify({ sent: 0, message: "No customer emails on file" }), {
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const user = Deno.env.get("GMAIL_USER")!;
    const pass = Deno.env.get("GMAIL_APP_PASSWORD")!;
    const subj = (subject ?? "StockFlow update").toString();
    const text = (body ?? "").toString();

    const html = `<div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden">
      <div style="background:#0D7A52;padding:18px 22px"><h2 style="color:#fff;margin:0;font-size:20px">StockFlow</h2></div>
      <div style="padding:22px;color:#1a1a1a;font-size:15px;line-height:1.6">
        <h3 style="margin:0 0 10px;color:#0D7A52">${subj}</h3>
        <p style="margin:0">${text.replace(/\n/g, "<br>")}</p>
      </div>
      <div style="padding:14px 22px;background:#f9fafb;color:#888;font-size:12px">Central Store Ordering — please do not reply to this email.</div>
    </div>`;

    const client = new SMTPClient({
      connection: {
        hostname: "smtp.gmail.com",
        port: 465,
        tls: true,
        auth: { username: user, password: pass },
      },
    });

    // Batch BCC in groups of 40 (keeps under provider per-message recipient caps).
    let sent = 0;
    for (let i = 0; i < emails.length; i += 40) {
      const chunk = emails.slice(i, i + 40);
      await client.send({
        from: `StockFlow <${user}>`,
        to: user,
        bcc: chunk,
        subject: subj,
        content: text || subj,
        html,
      });
      sent += chunk.length;
    }
    await client.close();

    return new Response(JSON.stringify({ sent }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
