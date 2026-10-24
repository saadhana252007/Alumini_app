// Sends (or SIMULATES) the e-mail notification for a booking request.
//
// Secrets (supabase secrets set ...):
//   RESEND_API_KEY  - optional. Without it, e-mails are logged as SIMULATED.
//   EMAIL_FROM      - e.g. "IIT (ISM) EDC <edc-noreply@your-domain>"
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by Supabase.
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    const { request_id, event } = await req.json();
    if (!["submitted", "decision"].includes(event)) return json({ error: "Invalid event." }, 400);

    // Read the request with the CALLER's rights (RLS) - proves they may see it.
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: r, error } = await userClient
      .from("booking_requests")
      .select("id,reference,visitor_name,email,indenter_email,status,room_type,arrival_at,departure_at,rejection_reason,allotted_room_no")
      .eq("id", request_id)
      .maybeSingle();
    if (error || !r) return json({ error: "Request not found or access denied." }, 403);
    if (event === "decision" && !["approved", "rejected"].includes(r.status)) {
      return json({ error: "No final decision has been made yet." }, 409);
    }

    const admin = createClient(url, service);
    const logEvent = event === "submitted" ? "submitted" : `decision_${r.status}`;
    const { data: existing } = await admin
      .from("notification_logs").select("id").eq("request_id", r.id).eq("event", logEvent).limit(1);
    if (existing && existing.length > 0) return json({ ok: true, skipped: true, mode: "skipped" });

    const recipients = [...new Set([r.email, r.indenter_email].filter((x): x is string => !!x))];
    if (recipients.length === 0) return json({ ok: true, mode: "no-recipient" });

    const fmt = (d: string) => new Date(d).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
    const room = r.room_type === "suite" ? "Suite" : "Standard Room";
    let subject = "";
    let body = "";
    if (event === "submitted") {
      subject = `EDC booking request ${r.reference} received`;
      body = `Dear ${r.visitor_name},\n\nYour accommodation requisition ${r.reference} (${room}, ` +
        `${fmt(r.arrival_at)} to ${fmt(r.departure_at)}) has been received by the Executive Development ` +
        `Centre, IIT (ISM) Dhanbad. Bookings are provisional and subject to availability.\n\nRegards,\nEDC Office`;
    } else if (r.status === "approved") {
      subject = `EDC booking ${r.reference} approved`;
      body = `Dear ${r.visitor_name},\n\nYour booking ${r.reference} has been APPROVED.\n` +
        `Room: ${r.allotted_room_no ?? "to be informed"} (${room})\nArrival: ${fmt(r.arrival_at)}\n` +
        `Departure: ${fmt(r.departure_at)}\n\nRegards,\nEDC Office`;
    } else {
      subject = `EDC booking ${r.reference} not approved`;
      body = `Dear ${r.visitor_name},\n\nWe regret that booking ${r.reference} could not be approved.\n` +
        `Reason: ${r.rejection_reason ?? "not stated"}\n\nRegards,\nEDC Office`;
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("EMAIL_FROM");
    let overall: "sent" | "simulated" | "failed" = "simulated";

    for (const to of recipients) {
      let mode: "sent" | "simulated" | "failed" = "simulated";
      let err: string | null = null;
      let stored = body;
      if (apiKey && from) {
        try {
          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ from, to: [to], subject, text: body }),
          });
          if (res.ok) mode = "sent";
          else { mode = "failed"; err = `Mail provider responded ${res.status}`; }
        } catch (e) {
          mode = "failed"; err = String(e);
        }
      } else {
        stored = `[SIMULATED EMAIL - no message was sent; mail credentials are not configured]\n\n${body}`;
      }
      overall = mode === "sent" || overall === "sent" ? "sent" : mode === "failed" ? "failed" : overall;
      await admin.from("notification_logs").insert({
        request_id: r.id, event: logEvent, recipient: to, subject, body: stored, mode, error: err,
      });
    }
    return json({ ok: true, mode: overall });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
