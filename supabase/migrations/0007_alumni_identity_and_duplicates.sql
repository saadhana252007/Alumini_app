-- Migration 0007_alumni_identity_and_duplicates.sql
-- Duplicate detection, identity matching, normalizers, alumni claims, and unique identity enforcement.

-- 1. Normalization Functions
create or replace function public.normalize_email(p_email text) returns text
language sql immutable as $$
  select nullif(lower(trim(p_email)), '');
$$;

create or replace function public.normalize_admission_no(p_adm text) returns text
language sql immutable as $$
  select nullif(upper(regexp_replace(trim(p_adm), '[^a-zA-Z0-9]', '', 'g')), '');
$$;

create or replace function public.normalize_phone(p_phone text) returns text
language plpgsql immutable as $$
declare
  cleaned text;
begin
  if p_phone is null then return null; end if;
  cleaned := regexp_replace(p_phone, '[^0-9]', '', 'g');
  if length(cleaned) = 10 then
    return '+91' || cleaned;
  elsif length(cleaned) = 11 and left(cleaned, 1) = '0' then
    return '+91' || substring(cleaned from 2);
  elsif length(cleaned) = 12 and left(cleaned, 2) = '91' then
    return '+' || cleaned;
  elsif length(cleaned) > 0 then
    return '+' || cleaned;
  else
    return null;
  end if;
end;
$$;

-- 2. Extend Profiles Table for Identity Matching & Duplicates
alter table public.profiles
  add column if not exists email_normalized text,
  add column if not exists contact_e164 text,
  add column if not exists admission_no_normalized text,
  add column if not exists possible_duplicate_of uuid references public.profiles(id) on delete set null,
  add column if not exists duplicate_review_status text default 'none' check (duplicate_review_status in ('none','pending','cleared','merged'));

-- 3. Trigger to Auto-Populate Normalized Identity Fields
create or replace function public.trg_profiles_normalize_identity() returns trigger
language plpgsql as $$
begin
  new.email_normalized := public.normalize_email(new.email);
  new.contact_e164 := public.normalize_phone(new.contact_no);
  new.admission_no_normalized := public.normalize_admission_no(new.admission_no);
  return new;
end $$;

drop trigger if exists trg_profiles_normalize on public.profiles;
create trigger trg_profiles_normalize
  before insert or update on public.profiles
  for each row execute function public.trg_profiles_normalize_identity();

-- Backfill normalized fields for existing records
update public.profiles set
  email_normalized = public.normalize_email(email),
  contact_e164 = public.normalize_phone(contact_no),
  admission_no_normalized = public.normalize_admission_no(admission_no)
where email_normalized is null or contact_e164 is null;

-- Flag existing duplicates in legacy data so unique indexes don't conflict
update public.profiles p1
   set possible_duplicate_of = p2.id,
       duplicate_review_status = 'pending'
  from public.profiles p2
 where p1.contact_e164 = p2.contact_e164
   and p1.contact_e164 is not null
   and p1.id <> p2.id
   and p1.created_at > p2.created_at
   and p1.duplicate_review_status = 'none';

-- 4. Unique Indexes
create unique index if not exists profiles_email_normalized_idx 
  on public.profiles (email_normalized);

create unique index if not exists profiles_admission_no_normalized_idx 
  on public.profiles (admission_no_normalized) 
  where admission_no_normalized is not null;

create unique index if not exists profiles_contact_e164_idx 
  on public.profiles (contact_e164) 
  where contact_e164 is not null and duplicate_review_status <> 'pending';

-- 5. Table: alumni_claims (For ADMISSION_NO_CLAIMED claims)
create table if not exists public.alumni_claims (
  id uuid primary key default gen_random_uuid(),
  claimant_details jsonb not null,
  existing_profile_id uuid not null references public.profiles(id) on delete cascade,
  admission_no text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.alumni_claims enable row level security;
drop policy if exists "alumni_claims_insert" on public.alumni_claims;
create policy "alumni_claims_insert" on public.alumni_claims for insert with check (true);

drop policy if exists "alumni_claims_select" on public.alumni_claims;
create policy "alumni_claims_select" on public.alumni_claims for select using (true);

drop policy if exists "alumni_claims_update" on public.alumni_claims;
create policy "alumni_claims_update" on public.alumni_claims for update using (true);

-- 6. Remove rogue name matching in booking requests policy
drop policy if exists "Alumni can read their own booking requests" on public.booking_requests;
create policy "Alumni can read their own booking requests" on public.booking_requests
  for select using (
    created_by = auth.uid() or
    email = auth.jwt() ->> 'email' or
    auth.role() = 'authenticated'
  );

-- 7. Live Registration Availability Check RPC
create or replace function public.check_registration_availability(
  p_email text default null,
  p_phone text default null,
  p_admission_no text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_email_norm text;
  v_phone_e164 text;
  v_adm_norm text;
  v_match record;
  v_masked_email text;
begin
  -- 1. Check Email
  if p_email is not null and char_length(trim(p_email)) > 0 then
    v_email_norm := public.normalize_email(p_email);
    select id, email into v_match 
      from public.profiles 
     where email_normalized = v_email_norm or lower(trim(email)) = v_email_norm 
     limit 1;

    if v_match.id is not null then
      return jsonb_build_object(
        'available', false,
        'code', 'EMAIL_EXISTS',
        'field', 'email',
        'message', 'This email is already registered. Please log in or reset your password.'
      );
    end if;
  end if;

  -- 2. Check Contact Phone
  if p_phone is not null and char_length(trim(p_phone)) > 0 then
    v_phone_e164 := public.normalize_phone(p_phone);
    if v_phone_e164 is not null then
      select id, email into v_match 
        from public.profiles 
       where contact_e164 = v_phone_e164 or contact_no = p_phone 
       limit 1;

      if v_match.id is not null then
        v_masked_email := regexp_replace(v_match.email, '(^.).*(@.*$)', '\1•••••\2');
        return jsonb_build_object(
          'available', false,
          'code', 'PHONE_EXISTS',
          'field', 'contact_no',
          'message', 'This mobile number is already linked to an alumni account (' || v_masked_email || '). Log in, or use a different number.',
          'hint', jsonb_build_object('maskedEmail', v_masked_email)
        );
      end if;
    end if;
  end if;

  -- 3. Check Admission Number
  if p_admission_no is not null and char_length(trim(p_admission_no)) > 0 then
    v_adm_norm := public.normalize_admission_no(p_admission_no);
    if v_adm_norm is not null then
      select id, email into v_match 
        from public.profiles 
       where admission_no_normalized = v_adm_norm or upper(trim(admission_no)) = v_adm_norm 
       limit 1;

      if v_match.id is not null then
        return jsonb_build_object(
          'available', false,
          'code', 'ADMISSION_NO_CLAIMED',
          'field', 'admission_no',
          'existing_profile_id', v_match.id,
          'message', 'This admission number is already registered. If this is you, submit a verification request; if you made a typo, please correct it.'
        );
      end if;
    end if;
  end if;

  return jsonb_build_object('available', true, 'code', 'AVAILABLE');
end $$;

grant execute on function public.check_registration_availability(text, text, text) to anon, authenticated;

-- 8. RPC: Admin Resolution of Flagged Duplicates
create or replace function public.resolve_duplicate_review(
  p_profile_id uuid,
  p_action text,
  p_master_profile_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  target_profile public.profiles;
begin
  select * into target_profile from public.profiles where id = p_profile_id;
  if target_profile.id is null then
    raise exception 'Profile not found.';
  end if;

  if p_action = 'clear' then
    update public.profiles 
       set duplicate_review_status = 'cleared', 
           possible_duplicate_of = null 
     where id = p_profile_id;

    insert into public.audit_logs (actor_id, action, entity_table, entity_id, description)
    values (auth.uid(), 'duplicate.cleared', 'profiles', p_profile_id, 'Duplicate flag cleared. Marked not a duplicate.');

    return jsonb_build_object('success', true, 'status', 'cleared');

  elsif p_action = 'reject' then
    update public.profiles 
       set verification_status = 'rejected', 
           duplicate_review_status = 'cleared',
           is_active = false 
     where id = p_profile_id;

    insert into public.audit_logs (actor_id, action, entity_table, entity_id, description)
    values (auth.uid(), 'duplicate.rejected', 'profiles', p_profile_id, 'Duplicate registration rejected.');

    return jsonb_build_object('success', true, 'status', 'rejected');

  elsif p_action = 'merge' then
    if p_master_profile_id is null then
      raise exception 'Master profile ID required for merge.';
    end if;

    -- Repoint booking requests
    update public.booking_requests 
       set created_by = p_master_profile_id 
     where created_by = p_profile_id;

    -- Repoint activity log
    update public.user_activity_log 
       set user_id = p_master_profile_id 
     where user_id = p_profile_id;

    -- Repoint donations
    update public.donation_intents 
       set user_id = p_master_profile_id 
     where user_id = p_profile_id;

    -- Archive old duplicate profile
    update public.profiles 
       set duplicate_review_status = 'merged',
           is_active = false,
           verification_status = 'rejected'
     where id = p_profile_id;

    insert into public.audit_logs (actor_id, action, entity_table, entity_id, description)
    values (auth.uid(), 'duplicate.merged', 'profiles', p_profile_id, 'Profile merged into master profile ' || p_master_profile_id::text);

    return jsonb_build_object('success', true, 'status', 'merged');
  else
    raise exception 'Invalid action: %', p_action;
  end if;
end $$;

grant execute on function public.resolve_duplicate_review(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';
