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

// ---------- Firebase (Android apps) ----------
let fcmToken: { token: string; exp: number; project: string } | null = null;

const b64url = (data: ArrayBuffer | string) => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

// Google access token from the Firebase service account (kept in Vault).
async function fcmAccess(): Promise<{ token: string; project: string } | null> {
  if (fcmToken && fcmToken.exp > Date.now() + 60_000) return fcmToken;
  const raw = await secret("firebase_service_account");
  if (!raw) return null;
  const sa = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claim}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${header}.${claim}.${b64url(sig)}`,
  });
  const j = await r.json();
  if (!j.access_token) { console.log("fcm auth failed", JSON.stringify(j).slice(0, 200)); return null; }
  fcmToken = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000, project: sa.project_id };
  return fcmToken;
}

async function sendFcm(token: string, n: { title: string; body: string; category: string }) {
  const a = await fcmAccess();
  if (!a) return "not_configured";
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${a.project}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${a.token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ message: {
      token,
      notification: { title: n.title, body: n.body },
      android: { priority: "HIGH", notification: { tag: n.category, sound: "default" } },
      data: { category: n.category },
    } }),
  });
  if (r.ok) return "ok";
  const j = await r.json().catch(() => ({}));
  const code = j?.error?.details?.[0]?.errorCode ?? j?.error?.status;
  return code === "UNREGISTERED" || code === "NOT_FOUND" ? "gone" : `error ${code}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const hook = await secret("hook_secret");
  if (!hook || req.headers.get("x-goride-hook") !== hook) return new Response("forbidden", { status: 403 });

  const { notification_id } = await req.json();
  const { data: n } = await admin.from("notifications").select("*").eq("id", notification_id).maybeSingle();
  if (!n) return new Response("not found", { status: 404 });

  const { data: pub } = await admin.from("integration_settings").select("value").eq("key", "vapid_public_key").maybeSingle();
  const priv = await secret("vapid_private_key");
  if (pub?.value && priv) webpush.setVapidDetails("mailto:temidayohassan2023@gmail.com", pub.value, priv);

  const { data: subs } = await admin.from("push_subscriptions").select("*").eq("user_id", n.user_id);
  const payload = JSON.stringify({
    title: n.title, body: n.body, tag: n.category, url: route(n.category, n.data),
  });
  let sent = 0;
  for (const s of subs ?? []) {
    // Android apps (Firebase).
    if (s.endpoint.startsWith("fcm:")) {
      const res = await sendFcm(s.endpoint.slice(4), n);
      if (res === "ok") sent++;
      else if (res === "gone") await admin.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
      else console.log("fcm", res);
      continue;
    }
    if (!pub?.value || !priv) continue;
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
