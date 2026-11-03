// GoRide push notifications (Web Push). Called by the database when a
// notification is created. Signing keys live in Supabase Vault.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const secret = async (k: string) => ((await admin.rpc("get_secret", { p_key: k })).data as string | null) ?? null;

// Where each notification opens in the app.
const route = (cat: string, data: Record<string, unknown> | null) => {
  if (data?.trip_id) return "#/home";
  if (cat === "payments" || cat === "earnings") return "#/wallet";
  return "#/notifications";
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const hook = await secret("hook_secret");
  if (!hook || req.headers.get("x-goride-hook") !== hook) return new Response("forbidden", { status: 403 });

  const { notification_id } = await req.json();
  const { data: n } = await admin.from("notifications").select("*").eq("id", notification_id).maybeSingle();
  if (!n) return new Response("not found", { status: 404 });

  const { data: pub } = await admin.from("integration_settings").select("value").eq("key", "vapid_public_key").maybeSingle();
  const priv = await secret("vapid_private_key");
  if (!pub?.value || !priv) return new Response("not configured", { status: 400 });
  webpush.setVapidDetails("mailto:temidayohassan2023@gmail.com", pub.value, priv);

  const { data: subs } = await admin.from("push_subscriptions").select("*").eq("user_id", n.user_id);
  const payload = JSON.stringify({
    title: n.title, body: n.body, tag: n.category, url: route(n.category, n.data),
  });
  let sent = 0;
  for (const s of subs ?? []) {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600, urgency: "high" });
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      // The browser unsubscribed: forget it.
      if (code === 404 || code === 410) await admin.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
      else console.log("push failed", code, String(e).slice(0, 200));
    }
  }
  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
