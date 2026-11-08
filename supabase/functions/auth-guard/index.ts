// Login protection for email-code sign-in (account lockout + IP limits).
//   {action:"can_send"|"can_verify", email}  -> {ok, message?}
//   {action:"record", email, ok:boolean}       -> {ok}
//   {action:"sent", email}                     -> {ok}
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  const email = String(body.email ?? "").slice(0, 200);
  // The caller's real IP (first address added by the edge network).
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || null;

  const action = String(body.action ?? "");
  const map: Record<string, string> = {
    can_send: "can_send", can_verify: "check", sent: "send",
    record: body.ok === true ? "success" : "fail",
  };
  const p_action = map[action];
  if (!p_action) return json({ error: "Unknown action" }, 400);

  const { data, error } = await admin.rpc("auth_guard", { p_email: email, p_ip: ip, p_action });
  if (error) return json({ ok: true }); // never block sign-in because of our own error
  return json(data ? { ok: false, message: data } : { ok: true });
});
