// GoRide Paystack server function.
// The Paystack SECRET key is read from Supabase Vault (set in the admin
// dashboard > Integrations); it never reaches the apps.
//
//   POST {action:"init", amount, purpose}  -> {authorization_url, reference}
//   POST {action:"verify", reference}      -> {status}
//   POST (from Paystack, signed webhook)   -> credits the wallet
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

async function secretKey(): Promise<string | null> {
  const { data } = await admin.rpc("get_secret", { p_key: "paystack_secret_key" });
  return (data as string | null) ?? null;
}

async function hmac512(key: string, body: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyAndCredit(sk: string, reference: string) {
  const r = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
    headers: { Authorization: `Bearer ${sk}` },
  });
  const j = await r.json();
  const status = j?.data?.status ?? "unknown";
  if (status === "success") {
    await admin.rpc("credit_paystack", { p_reference: reference, p_amount_kobo: j.data.amount });
  } else if (status === "failed" || status === "abandoned") {
    await admin.from("paystack_payments").update({ status: "failed" }).eq("reference", reference).eq("status", "pending");
  }
  return status;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const raw = await req.text();
  const sk = await secretKey();

  // Webhook from Paystack (signed with the secret key).
  const signature = req.headers.get("x-paystack-signature");
  if (signature) {
    if (!sk || (await hmac512(sk, raw)) !== signature) return json({ error: "bad signature" }, 401);
    const event = JSON.parse(raw);
    if (event?.event === "charge.success") {
      await admin.rpc("credit_paystack", { p_reference: event.data.reference, p_amount_kobo: event.data.amount });
    }
    return json({ ok: true });
  }

  // App calls: must be a signed-in GoRide user.
  const jwt = (req.headers.get("authorization") ?? "").replace("Bearer ", "");
  const { data: auth } = await admin.auth.getUser(jwt);
  const user = auth?.user;
  if (!user) return json({ error: "Please sign in again." }, 401);
  if (!sk) return json({ error: "not_configured" }, 400);

  let body: Record<string, unknown> = {};
  try { body = JSON.parse(raw || "{}"); } catch { /* empty */ }

  if (body.action === "init") {
    const amount = Math.round(Number(body.amount));
    if (!Number.isFinite(amount) || amount < 100 || amount > 500000) {
      return json({ error: "Amount must be between 100 and 500,000 naira." }, 400);
    }
    const purpose = body.purpose === "settle" ? "settle" : "top_up";
    const reference = `GR-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const { error } = await admin.from("paystack_payments").insert({ reference, user_id: user.id, amount, purpose });
    if (error) return json({ error: error.message }, 400);
    const r = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: user.email ?? `${user.id}@goride.app`,
        amount: amount * 100,
        reference,
        currency: "NGN",
        callback_url: typeof body.callback_url === "string" ? body.callback_url : undefined,
        metadata: { user_id: user.id, purpose },
      }),
    });
    const j = await r.json();
    if (!j?.status) return json({ error: j?.message ?? "Paystack could not start the payment." }, 400);
    return json({ authorization_url: j.data.authorization_url, reference });
  }

  if (body.action === "verify") {
    const reference = String(body.reference ?? "");
    const { data: p } = await admin.from("paystack_payments").select("user_id, status").eq("reference", reference).maybeSingle();
    if (!p || p.user_id !== user.id) return json({ error: "Payment not found" }, 404);
    if (p.status === "success") return json({ status: "success" });
    return json({ status: await verifyAndCredit(sk, reference) });
  }

  return json({ error: "Unknown action" }, 400);
});
