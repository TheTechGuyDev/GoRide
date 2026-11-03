// Applies the email (SMTP) and Google sign-in keys saved in the admin
// dashboard > Integrations to Supabase Auth. Super Admins only.
// Needs the "Supabase access token" integration (stored encrypted in Vault).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const url = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const ref = new URL(url).hostname.split(".")[0];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const jwt = (req.headers.get("authorization") ?? "").replace("Bearer ", "");
  const { data: auth } = await admin.auth.getUser(jwt);
  const uid = auth?.user?.id;
  if (!uid) return json({ error: "Please sign in again." }, 401);
  const { data: me } = await admin.from("staff").select("role, active").eq("id", uid).maybeSingle();
  if (!me?.active || me.role !== "super_admin") return json({ error: "Only a Super Admin can do this." }, 403);

  const secret = async (k: string) => (await admin.rpc("get_secret", { p_key: k })).data as string | null;
  const { data: rows } = await admin.from("integration_settings").select("key, value").eq("is_secret", false);
  const pub = Object.fromEntries((rows ?? []).map((r) => [r.key, r.value]));

  const token = await secret("supabase_access_token");
  if (!token) return json({ error: "Add the Supabase access token first." }, 400);

  const config: Record<string, unknown> = {};
  const smtpPass = await secret("smtp_password");
  if (pub.smtp_user && smtpPass) {
    Object.assign(config, {
      smtp_host: pub.smtp_host ?? "smtp.gmail.com",
      smtp_port: String(pub.smtp_port ?? "465"),
      smtp_user: pub.smtp_user,
      smtp_pass: smtpPass,
      smtp_admin_email: pub.smtp_sender ?? pub.smtp_user,
      smtp_sender_name: "GoRide",
    });
  }
  const googleSecret = await secret("google_client_secret");
  if (pub.google_client_id && googleSecret) {
    Object.assign(config, {
      external_google_enabled: true,
      external_google_client_id: pub.google_client_id,
      external_google_secret: googleSecret,
    });
  }
  if (Object.keys(config).length === 0) return json({ error: "Nothing to apply yet." }, 400);

  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(config),
  });
  if (!r.ok) return json({ error: `Supabase refused the change (${r.status}). Check the access token.` }, 400);
  return json({ ok: true, applied: Object.keys(config).length });
});
