// Supabase Edge Function: alumni-register
// Enforces strict identity rules, duplicate detection, and insert-only profile creation.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Rate limiter: max 10 registration attempts per IP per hour
const ipAttempts = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const record = ipAttempts.get(ip);
  if (!record || now > record.resetAt) {
    ipAttempts.set(ip, { count: 1, resetAt: now + 3600 * 1000 });
    return true;
  }
  if (record.count >= 10) {
    return false;
  }
  record.count++;
  return true;
}

// Helper normalizers
function normalizeEmail(email?: string): string {
  return (email || "").trim().toLowerCase();
}

function normalizePhone(phone?: string): string {
  if (!phone) return "";
  const raw = phone.trim();
  if (raw.startsWith("+")) {
    const digits = raw.substring(1).replace(/\D/g, "");
    return `+${digits}`;
  }
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10) {
    return `+91${digits}`;
  } else if (digits.length === 11 && digits.startsWith("0")) {
    return `+91${digits.substring(1)}`;
  } else if (digits.length === 12 && digits.startsWith("91")) {
    return `+${digits}`;
  } else if (digits.length > 0) {
    return `+${digits}`;
  }
  return "";
}

function normalizeAdmissionNo(adm?: string): string | null {
  if (!adm) return null;
  const cleaned = adm.replace(/[^a-zA-Z0-9]/g, "").toUpperCase().trim();
  return cleaned.length > 0 ? cleaned : null;
}

function maskEmail(email?: string): string {
  if (!email || !email.includes("@")) return "•••••@email.com";
  const [user, domain] = email.trim().toLowerCase().split("@");
  if (!user) return `•••••@${domain}`;
  return `${user[0]}•••••@${domain}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const clientIp =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (!checkRateLimit(clientIp)) {
    return new Response(
      JSON.stringify({
        ok: false,
        code: "RATE_LIMITED",
        message: "Too many registration attempts. Please try again in an hour.",
      }),
      { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.json();
    const {
      email,
      password,
      fullName,
      admissionNo,
      contactNo,
      whatsappNo,
      departmentId,
      batchYear,
      currentPosition,
      organisation,
      addressLine,
      city,
      state,
      country,
      pincode,
      photoUrl,
    } = body;

    // Basic payload validations
    if (!email || !password || !fullName || !contactNo) {
      return new Response(
        JSON.stringify({
          ok: false,
          code: "VALIDATION_ERROR",
          message: "Email, password, full name, and mobile number are required.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const emailNorm = normalizeEmail(email);
    const phoneE164 = normalizePhone(contactNo);
    const admNorm = normalizeAdmissionNo(admissionNo);
    const nameClean = (fullName || "").trim();
    const whatsappClean = normalizePhone(whatsappNo || contactNo);
    const parsedBatch = batchYear ? parseInt(batchYear) : null;

    // =========================================================================
    // AUTHORITATIVE DECISION FLOW (Evaluated in strict order)
    // =========================================================================

    // 1. EMAIL_EXISTS
    const { data: emailMatch } = await supabaseAdmin
      .from("profiles")
      .select("id, email")
      .or(`email_normalized.eq.${emailNorm},email.ilike.${emailNorm}`)
      .maybeSingle();

    if (emailMatch) {
      return new Response(
        JSON.stringify({
          ok: false,
          code: "EMAIL_EXISTS",
          field: "email",
          message: "This email is already registered. Please log in or reset your password.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. PHONE_EXISTS
    const { data: phoneMatch } = await supabaseAdmin
      .from("profiles")
      .select("id, email, contact_no, contact_e164")
      .or(`contact_e164.eq.${phoneE164},contact_no.eq.${contactNo.trim()}`)
      .maybeSingle();

    if (phoneMatch) {
      const masked = maskEmail(phoneMatch.email);
      return new Response(
        JSON.stringify({
          ok: false,
          code: "PHONE_EXISTS",
          field: "contact_no",
          message: `This mobile number is already linked to an alumni account (${masked}). Log in, or use a different number.`,
          hint: { maskedEmail: masked },
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. ADMISSION_NO_CLAIMED (Only checked if admissionNo was provided)
    if (admNorm) {
      const { data: admMatch } = await supabaseAdmin
        .from("profiles")
        .select("id, email, contact_e164, full_name")
        .or(`admission_no_normalized.eq.${admNorm},admission_no.ilike.${admNorm}`)
        .maybeSingle();

      if (admMatch) {
        return new Response(
          JSON.stringify({
            ok: false,
            code: "ADMISSION_NO_CLAIMED",
            field: "admission_no",
            existingProfileId: admMatch.id,
            message:
              "This admission number is already registered. If this is you, submit a verification request; if you made a typo, please correct it.",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 4. SOFT MATCH: Name + Department + Batch Year all match
    // Name alone is NEVER a key. But if all 3 match with different email & phone,
    // we allow registration but flag for admin review.
    let possibleDuplicateOf: string | null = null;
    let duplicateReviewStatus: "none" | "pending" = "none";
    let verificationStatus = "pending";

    if (departmentId && parsedBatch) {
      const { data: softMatches } = await supabaseAdmin
        .from("profiles")
        .select("id, full_name, department_id, batch_year")
        .eq("department_id", departmentId)
        .eq("batch_year", parsedBatch);

      if (softMatches && softMatches.length > 0) {
        const exactNameSoftMatch = softMatches.find(
          (p) =>
            p.full_name &&
            p.full_name.trim().toLowerCase() === nameClean.toLowerCase()
        );
        if (exactNameSoftMatch) {
          possibleDuplicateOf = exactNameSoftMatch.id;
          duplicateReviewStatus = "pending";
          verificationStatus = "pending";
        }
      }
    }

    // 5. NO DUPLICATE / CLEAN REGISTRATION
    // Check auto-verification against alumni_registry (if not flagged as duplicate)
    if (!possibleDuplicateOf && admNorm) {
      const { data: regMatch } = await supabaseAdmin
        .from("alumni_registry")
        .select("id, full_name, batch_year, department_code")
        .eq("admission_no", admNorm)
        .maybeSingle();

      if (regMatch) {
        // Auto-verify if admission number is authenticated in the official registry
        verificationStatus = "verified";
      }
    }

    // =========================================================================
    // EXECUTION: Create Auth User & INSERT INTO PROFILES (Insert only!)
    // =========================================================================

    // Create Supabase Auth user
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: emailNorm,
      password: password,
      email_confirm: true,
      user_metadata: {
        full_name: nameClean,
        role: "alumni",
        contact_no: phoneE164,
        admission_no: admNorm,
      },
    });

    if (authError || !authData.user) {
      return new Response(
        JSON.stringify({
          ok: false,
          code: "AUTH_ERROR",
          message: authError?.message || "User creation failed",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = authData.user.id;

    // Profile insertion: MUST BE INSERT ONLY. Never upsert!
    const { error: profileError } = await supabaseAdmin.from("profiles").insert({
      id: userId,
      full_name: nameClean,
      email: emailNorm,
      email_normalized: emailNorm,
      role: "alumni",
      is_active: true,
      admission_no: admNorm,
      admission_no_normalized: admNorm,
      contact_no: phoneE164,
      contact_e164: phoneE164,
      whatsapp_no: whatsappClean,
      department_id: departmentId || null,
      batch_year: parsedBatch,
      current_position: currentPosition?.trim() || null,
      organisation: organisation?.trim() || null,
      address_line: addressLine?.trim() || null,
      city: city?.trim() || null,
      state: state?.trim() || null,
      country: country || "India",
      pincode: pincode?.trim() || null,
      photo_url: photoUrl || null,
      verification_status: verificationStatus,
      possible_duplicate_of: possibleDuplicateOf,
      duplicate_review_status: duplicateReviewStatus,
      consent_at: new Date().toISOString(),
    });

    if (profileError) {
      // Rollback auth user
      await supabaseAdmin.auth.admin.deleteUser(userId);

      // Handle race condition on unique index (Postgres 23505)
      if (profileError.code === "23505" || profileError.message.includes("unique")) {
        if (profileError.message.includes("email")) {
          return new Response(
            JSON.stringify({
              ok: false,
              code: "EMAIL_EXISTS",
              field: "email",
              message: "This email is already registered. Please log in or reset your password.",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else if (profileError.message.includes("contact")) {
          return new Response(
            JSON.stringify({
              ok: false,
              code: "PHONE_EXISTS",
              field: "contact_no",
              message: "This mobile number is already linked to an alumni account.",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else if (profileError.message.includes("admission")) {
          return new Response(
            JSON.stringify({
              ok: false,
              code: "ADMISSION_NO_CLAIMED",
              field: "admission_no",
              message: "This admission number is already registered.",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      return new Response(
        JSON.stringify({ ok: false, code: "DATABASE_ERROR", message: profileError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Log registration in user activity
    await supabaseAdmin.from("user_activity_log").insert({
      user_id: userId,
      action_type: "registration",
      title: "Welcome to the IIT (ISM) Alumni Family",
      description: possibleDuplicateOf
        ? "Registration submitted. Flagged for identity review."
        : `Registration submitted (${verificationStatus === "verified" ? "Auto-verified via Registry" : "Verification in progress"}).`,
    });

    return new Response(
      JSON.stringify({
        ok: true,
        userId: userId,
        verificationStatus: verificationStatus,
        flagged: possibleDuplicateOf !== null,
        message: possibleDuplicateOf
          ? "Your registration is under review."
          : "Registration completed successfully.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ ok: false, code: "SERVER_ERROR", message: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
