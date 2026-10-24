#!/usr/bin/env node
// Bootstraps an administrator account (use it for the FIRST Super Admin and for
// optional demo accounts). Needs Node 18+. Nothing is hardcoded: every value is
// read from the environment, and the service-role key never leaves your machine.
//
//   SUPABASE_URL=https://xxxx.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=... \
//   ADMIN_EMAIL=you@iitism.ac.in ADMIN_NAME="Your Name" \
//   ADMIN_ROLE=super_admin ADMIN_PASSWORD='a-long-password-12+' \
//   node scripts/create_admin.mjs
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_NAME, ADMIN_ROLE, ADMIN_PASSWORD } = process.env;
const roles = ["edc_admin", "dean_admin", "super_admin"];

function fail(msg) { console.error(`Error: ${msg}`); process.exit(1); }
for (const [k, v] of Object.entries({ SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_NAME, ADMIN_ROLE, ADMIN_PASSWORD })) {
  if (!v) fail(`${k} is required.`);
}
if (!roles.includes(ADMIN_ROLE)) fail(`ADMIN_ROLE must be one of ${roles.join(", ")}.`);
if (ADMIN_PASSWORD.length < 12) fail("ADMIN_PASSWORD must be at least 12 characters.");

const headers = {
  apikey: SUPABASE_SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

const u = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
  method: "POST", headers,
  body: JSON.stringify({ email: ADMIN_EMAIL.toLowerCase(), password: ADMIN_PASSWORD, email_confirm: true }),
});
const user = await u.json();
if (!u.ok) fail(user.msg || user.message || JSON.stringify(user));

const p = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
  method: "POST", headers: { ...headers, Prefer: "return=minimal" },
  body: JSON.stringify({ id: user.id, full_name: ADMIN_NAME, email: ADMIN_EMAIL.toLowerCase(), role: ADMIN_ROLE }),
});
if (!p.ok) {
  await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${user.id}`, { method: "DELETE", headers });
  fail(`Profile creation failed: ${await p.text()}`);
}
console.log(`Created ${ADMIN_ROLE} account for ${ADMIN_EMAIL}.`);
