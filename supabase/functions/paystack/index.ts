// GoRide Paystack server function.
// The Paystack SECRET key is read from Supabase Vault (set in the admin
// dashboard > Integrations); it never reaches the apps.
//
//   POST {action:"init", amount, purpose}  -> {authorization_url, reference}
//   POST {action:"verify", reference}      -> {status}
//   POST {action:"charge_card", card_id, amount, purpose} -> {status}
//   POST (from Paystack, signed webhook)   -> credits the wallet
//   POST (from our database, hook secret)  {action:"charge_trip"} -> charges a card trip
// Successful card payments save the card (Paystack authorization) for reuse.
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

// Paystack's local card fee: 1.5% + N100 (the N100 waived under N2,500),
// capped at N2,000. The payer covers it, so the full amount reaches GoRide.
export function feeFor(amount: number): number {
  let gross = Math.ceil(amount / 0.985);
  if (gross >= 2500) gross = Math.ceil((amount + 100) / 0.985);
  return Math.min(gross - amount, 2000);
}

// Credit the wallet and remember the card for next time.
async function credit(data: Record<string, any>) {
  await admin.rpc("credit_paystack", { p_reference: data.reference, p_amount_kobo: data.amount });
  if (data.authorization) {
    const { data: p } = await admin.from("paystack_payments").select("user_id").eq("reference", data.reference).maybeSingle();
    if (p) await admin.rpc("save_card", { p_user: p.user_id, p_auth: data.authorization, p_email: data.customer?.email ?? null });
  }
}

// Charge a saved card without the rider typing anything.
async function chargeSaved(sk: string, userId: string, cardId: string | null, amount: number, purpose: string) {
  let q = admin.from("payment_cards").select("id, authorization_code, email").eq("user_id", userId).not("authorization_code", "is", null);
  q = cardId ? q.eq("id", cardId) : q.order("is_default", { ascending: false }).order("created_at", { ascending: false });
  const { data: cards } = await q.limit(1);
  const card = cards?.[0];
  if (!card) return { status: "failed", error: "No saved card" };
  const reference = `GRC-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
  const fee = feeFor(amount);
  const { error } = await admin.from("paystack_payments").insert({ reference, user_id: userId, amount, purpose, fee });
  if (error) return { status: "failed", error: error.message };
  let email = card.email;
  if (!email) email = (await admin.auth.admin.getUserById(userId)).data.user?.email ?? `${userId}@goride.app`;
  const r = await fetch("https://api.paystack.co/transaction/charge_authorization", {
    method: "POST",
    headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" },
    body: JSON.stringify({ authorization_code: card.authorization_code, email, amount: (amount + fee) * 100, reference, currency: "NGN" }),
  });
  const j = await r.json();
  const status = j?.data?.status ?? "failed";
  if (status === "success") await credit(j.data);
  else if (status !== "pending" && status !== "ongoing") {
    await admin.from("paystack_payments").update({ status: "failed" }).eq("reference", reference);
  }
  return { status, reference, error: status === "success" ? null : (j?.data?.gateway_response ?? j?.message ?? "Card was declined") };
}

async function verifyAndCredit(sk: string, reference: string) {
  const r = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
    headers: { Authorization: `Bearer ${sk}` },
  });
  const j = await r.json();
  const status = j?.data?.status ?? "unknown";
  if (status === "success") {
    await credit(j.data);
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
      await credit(event.data);
    }
    return json({ ok: true });
  }

  // From our own database: charge the card for a finished card trip.
  const hook = req.headers.get("x-goride-hook");
  if (hook) {
    const { data: hs } = await admin.rpc("get_secret", { p_key: "hook_secret" });
    if (hook !== hs) return json({ error: "forbidden" }, 403);
    const body = JSON.parse(raw || "{}");
    if (body.action !== "charge_trip") return json({ error: "Unknown action" }, 400);
    const { data: c } = await admin.from("card_charges").select("*").eq("id", body.charge_id).eq("status", "pending").maybeSingle();
    if (!c) return json({ ok: true });
    const res = sk ? await chargeSaved(sk, c.user_id, c.card_id, c.amount, "card_trip") : { status: "failed", error: "Payments not set up" };
    const ok = res.status === "success";
    await admin.from("card_charges").update({ status: ok ? "success" : "failed", error: res.error }).eq("id", c.id);
    if (!ok) {
      await admin.from("notifications").insert({
        user_id: c.user_id, category: "payments", title: "Card payment failed",
        body: `We could not charge your card ${c.amount} naira for your last trip, so it was taken from your wallet. If your balance is below zero, top up to book again.`,
      });
    }
    return json(res);
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
    const purpose = ["settle", "add_card"].includes(String(body.purpose)) ? String(body.purpose) : "top_up";
    const reference = `GR-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const fee = feeFor(amount);
    const { error } = await admin.from("paystack_payments").insert({ reference, user_id: user.id, amount, purpose, fee });
    if (error) return json({ error: error.message }, 400);
    const r = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: user.email ?? `${user.id}@goride.app`,
        amount: (amount + fee) * 100,
        reference,
        currency: "NGN",
        callback_url: typeof body.callback_url === "string" ? body.callback_url : undefined,
        metadata: { user_id: user.id, purpose },
      }),
    });
    const j = await r.json();
    if (!j?.status) return json({ error: j?.message ?? "Paystack could not start the payment." }, 400);
    return json({ authorization_url: j.data.authorization_url, reference, fee, total: amount + fee });
  }

  if (body.action === "verify") {
    const reference = String(body.reference ?? "");
    const { data: p } = await admin.from("paystack_payments").select("user_id, status").eq("reference", reference).maybeSingle();
    if (!p || p.user_id !== user.id) return json({ error: "Payment not found" }, 404);
    if (p.status === "success") return json({ status: "success" });
    return json({ status: await verifyAndCredit(sk, reference) });
  }

  if (body.action === "charge_card") {
    const amount = Math.round(Number(body.amount));
    if (!Number.isFinite(amount) || amount < 100 || amount > 500000) {
      return json({ error: "Amount must be between 100 and 500,000 naira." }, 400);
    }
    const purpose = body.purpose === "settle" ? "settle" : "top_up";
    return json(await chargeSaved(sk, user.id, String(body.card_id ?? "") || null, amount, purpose));
  }

  return json({ error: "Unknown action" }, 400);
});
