// Creates an administrator account. Only callers holding `admin.manage` may use it.
// The service-role key stays on the server; it is never shipped in the Flutter app.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const ROLES = ["edc_admin", "dean_admin", "super_admin"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: allowed, error: permErr } = await userClient.rpc("has_permission", { perm: "admin.manage" });
    if (permErr || allowed !== true) return json({ error: "Not authorised." }, 403);

    const { email, full_name, role, password } = await req.json();
    if (typeof email !== "string" || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: "Invalid e-mail." }, 400);
    if (typeof full_name !== "string" || full_name.trim().length < 3) return json({ error: "Full name is required." }, 400);
    if (!ROLES.includes(role)) return json({ error: "Invalid role." }, 400);
    if (typeof password !== "string" || password.length < 12) return json({ error: "Password must be at least 12 characters." }, 400);

    const admin = createClient(url, service);
    const { data, error } = await admin.auth.admin.createUser({
      email: email.trim().toLowerCase(), password, email_confirm: true,
    });
    if (error || !data.user) return json({ error: error?.message ?? "Could not create the user." }, 400);

    const { error: pErr } = await admin.from("profiles").insert({
      id: data.user.id, full_name: full_name.trim(), email: email.trim().toLowerCase(), role,
    });
    if (pErr) {
      await admin.auth.admin.deleteUser(data.user.id);
      return json({ error: pErr.message }, 400);
    }
    return json({ ok: true, id: data.user.id }, 201);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
