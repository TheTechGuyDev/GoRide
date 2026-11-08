// Deletes the signed-in user's GoRide account (Google Play requirement).
// Personal data is wiped; trip and payment records stay, anonymised.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const url = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
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

  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: u } = await admin.auth.getUser(token);
  const user = u?.user;
  if (!user) return json({ error: "Please sign in again." }, 401);

  const { error } = await admin.rpc("anonymize_user", { p_user: user.id });
  if (error) return json({ error: error.message }, 400);

  // Photos and driver documents.
  for (const bucket of ["avatars", "driver-docs"]) {
    const { data: files } = await admin.storage.from(bucket).list(user.id);
    if (files?.length) await admin.storage.from(bucket).remove(files.map((f) => `${user.id}/${f.name}`));
  }

  // Soft delete: the login is removed; anonymised records stay linked.
  const del = await admin.auth.admin.deleteUser(user.id, true);
  if (del.error) return json({ error: del.error.message }, 500);
  return json({ ok: true });
});
