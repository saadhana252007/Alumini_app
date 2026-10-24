-- IIT (ISM) Dhanbad - EDC Admin App: core schema
-- Run migrations 0001..0005 in order (supabase db push, or the SQL editor).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null check (char_length(trim(full_name)) > 0),
  email       text not null,
  role        text not null check (role in ('edc_admin','dean_admin','super_admin')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
comment on table public.profiles is
  'Administrator profiles. Rows are created ONLY by the admin-create-user Edge Function or the bootstrap script - never by public sign-up.';

create table public.role_permissions (
  role        text not null check (role in ('edc_admin','dean_admin','super_admin')),
  permission  text not null,
  primary key (role, permission)
);

create table public.app_settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

-- --------------------------------------------------------------- helpers
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.is_active_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active);
$$;

create or replace function public.current_role_name() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and is_active;
$$;

create or replace function public.has_permission(perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.profiles pr
    join public.role_permissions rp on rp.role = pr.role
    where pr.id = auth.uid() and pr.is_active and rp.permission = perm
  );
$$;

-- ----------------------------------------------------------------- notices
create table public.notices (
  id            uuid primary key default gen_random_uuid(),
  title         text not null check (char_length(trim(title)) between 3 and 200),
  description   text not null default '',
  category      text not null default 'General',
  image_path    text,
  publish_date  date not null default current_date,
  expiry_date   date,
  status        text not null default 'draft' check (status in ('draft','published','archived')),
  created_by    uuid not null references public.profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint notices_dates_ok check (expiry_date is null or expiry_date >= publish_date)
);
create index notices_status_idx on public.notices (status, publish_date desc);
create index notices_creator_idx on public.notices (created_by);

-- ------------------------------------------------------- tariffs / workflow
create table public.tariff_rules (
  id                uuid primary key default gen_random_uuid(),
  visitor_category  text not null check (visitor_category in ('A','B','C','D','E')),
  sub_category      text not null default '' check (sub_category in ('','a','b','c')),
  room_type         text not null check (room_type in ('suite','standard')),
  rate              numeric(12,2) check (rate is null or rate >= 0),
  billing_unit      text not null check (billing_unit in ('per_day','per_month','free','as_applicable','unspecified')),
  note              text,
  is_active         boolean not null default true,
  updated_at        timestamptz not null default now(),
  unique (visitor_category, sub_category, room_type)
);

create table public.approval_workflows (
  id               uuid primary key default gen_random_uuid(),
  room_type        text not null check (room_type in ('suite','standard')),
  stage_order      int  not null check (stage_order >= 1),
  stage_name       text not null,
  authority_label  text not null default '',
  approver_role    text not null check (approver_role in ('edc_admin','dean_admin','super_admin')),
  is_active        boolean not null default true,
  unique (room_type, stage_order)
);

-- ------------------------------------------------------------ calculation
create or replace function public.calculate_charges(
  p_category text, p_sub text, p_room text, p_rooms int,
  p_arrival timestamptz, p_departure timestamptz
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  r public.tariff_rules;
  d int;
  gstp numeric := 0;
  sub numeric;
  gst numeric;
begin
  select * into r from public.tariff_rules
   where is_active and visitor_category = p_category and room_type = p_room
     and sub_category = coalesce(p_sub, '')
   limit 1;
  if r.id is null then
    select * into r from public.tariff_rules
     where is_active and visitor_category = p_category and room_type = p_room
       and sub_category = ''
     limit 1;
  end if;

  d := greatest(1, ceil(extract(epoch from (p_departure - p_arrival)) / 86400.0)::int);
  select coalesce((value #>> '{}')::numeric, 0) into gstp
    from public.app_settings where key = 'gst_percent';
  gstp := coalesce(gstp, 0);

  if r.id is null or r.billing_unit in ('as_applicable','unspecified')
     or (r.rate is null and r.billing_unit <> 'free') then
    return jsonb_build_object('days', d, 'rooms', p_rooms,
      'billing_unit', coalesce(r.billing_unit, 'unspecified'),
      'unit_rate', null, 'subtotal', null, 'gst_percent', gstp, 'gst', null, 'total', null,
      'note', 'Rate not specified in the EDC tariff; to be determined by the institute.');
  end if;

  if r.billing_unit = 'free' then
    return jsonb_build_object('days', d, 'rooms', p_rooms, 'billing_unit', 'free',
      'unit_rate', 0, 'subtotal', 0, 'gst_percent', gstp, 'gst', 0, 'total', 0,
      'note', 'Free boarding and lodging (Category A).');
  end if;

  if r.billing_unit = 'per_month' then
    sub := r.rate * ceil(d / 30.0) * p_rooms;
  else
    sub := r.rate * d * p_rooms;
  end if;
  sub := round(sub, 2);
  gst := round(sub * gstp / 100, 2);
  return jsonb_build_object('days', d, 'rooms', p_rooms, 'billing_unit', r.billing_unit,
    'unit_rate', r.rate, 'subtotal', sub, 'gst_percent', gstp, 'gst', gst,
    'total', round(sub + gst, 2),
    'note', case when r.billing_unit = 'per_month'
      then 'Monthly rate charged per started 30-day month (prototype assumption - confirm with the institute).'
      else null end);
end $$;

-- --------------------------------------------------------- booking requests
create sequence public.booking_ref_seq start 1;
create sequence public.receipt_no_seq start 1;

create table public.booking_requests (
  id                     uuid primary key default gen_random_uuid(),
  reference              text not null unique,

  -- Section 1: visitor & booking details (visitor / office entered)
  visitor_name           text not null check (char_length(trim(visitor_name)) > 0),
  organization           text,
  address                text not null check (char_length(trim(address)) > 0),
  nationality            text not null check (nationality in ('indian','foreigner')),
  mobile                 text not null check (mobile ~ '^[0-9+\-\s]{7,20}$'),
  email                  text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  purpose                text not null check (purpose in ('official','personal')),
  persons_lodging        int  not null default 1 check (persons_lodging >= 1),
  persons_food           int  not null default 0 check (persons_food >= 0),
  children_under_12      int  not null default 0 check (children_under_12 >= 0),
  guest_details          jsonb not null default '[]'::jsonb,
  num_rooms              int  not null default 1 check (num_rooms between 1 and 50),
  visitor_category       text not null check (visitor_category in ('A','B','C','D','E')),
  visitor_sub_category   text not null default '' check (visitor_sub_category in ('','a','b','c')),
  room_type              text not null check (room_type in ('suite','standard')),
  arrival_at             timestamptz not null,
  departure_at           timestamptz not null,

  -- Section 2: bills settled by
  lodging_billed_to      text not null default 'visitor'
    check (lodging_billed_to in ('visitor','indenter','department','institute','project_coordinator')),
  food_billed_to         text not null default 'visitor'
    check (food_billed_to in ('visitor','indenter','department','institute','project_coordinator')),

  -- Rules from the booking procedure
  is_student_guest       boolean not null default false,
  forwarded_by_dsw       boolean not null default false,
  extended_stay_approved boolean not null default false,

  -- Section 3: indenter
  indenter_name          text not null check (char_length(trim(indenter_name)) > 0),
  indenter_designation   text,
  indenter_emp_code      text,
  indenter_department    text,
  indenter_phone         text,
  indenter_email         text check (indenter_email is null or indenter_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  forwarding_authority   text check (forwarding_authority is null or forwarding_authority in ('hod','project_coordinator','dsw')),

  -- Section 4: office use only (written only by decide_request)
  availability           text check (availability in ('available','not_available')),
  allotted_room_no       text,

  -- Section 5: approval workflow state (written only by RPCs)
  status                 text not null default 'pending'
    check (status in ('pending','awaiting_approval','approved','rejected','cancelled','completed')),
  current_stage          int  not null default 1,
  rejection_reason       text,
  estimated_amount       numeric(12,2),

  created_by             uuid not null references public.profiles(id),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint br_dates_ok check (departure_at > arrival_at),
  constraint br_children_ok check (children_under_12 <= persons_lodging),
  constraint br_capacity_ok check ((persons_lodging - children_under_12) <= num_rooms * 2)
);
create index br_status_idx   on public.booking_requests (status, created_at desc);
create index br_arrival_idx  on public.booking_requests (arrival_at);
create index br_creator_idx  on public.booking_requests (created_by);
create index br_search_idx   on public.booking_requests (lower(visitor_name), lower(organization));

create or replace function public.booking_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare calc jsonb;
begin
  new.reference        := 'EDC-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.booking_ref_seq')::text, 6, '0');
  new.status           := 'pending';
  new.current_stage    := 1;
  new.created_by       := auth.uid();
  new.availability     := null;
  new.allotted_room_no := null;
  new.rejection_reason := null;

  if new.arrival_at < now() + interval '24 hours' then
    raise exception 'Bookings must be made at least 24 hours before arrival.';
  end if;
  if new.purpose = 'personal' and not new.extended_stay_approved
     and (new.departure_at - new.arrival_at) > interval '3 days' then
    raise exception 'Personal visits are limited to 3 days unless an extended stay was approved beforehand.';
  end if;
  if new.is_student_guest and not new.forwarded_by_dsw then
    raise exception 'Student requisitions must be forwarded by DSW.';
  end if;
  if new.visitor_category = 'E' and new.visitor_sub_category = '' then
    raise exception 'Category E requires a sub-type (a, b or c).';
  end if;

  calc := public.calculate_charges(new.visitor_category, new.visitor_sub_category,
            new.room_type, new.num_rooms, new.arrival_at, new.departure_at);
  new.estimated_amount := (calc ->> 'total')::numeric;
  return new;
end $$;

create trigger booking_before_insert before insert on public.booking_requests
  for each row execute function public.booking_before_insert();

-- Status transitions are validated in the database, whoever writes.
create or replace function public.booking_guard_update() returns trigger
language plpgsql as $$
begin
  if old.status <> new.status and not (
       (old.status = 'pending'           and new.status in ('awaiting_approval','approved','rejected','cancelled'))
    or (old.status = 'awaiting_approval' and new.status in ('approved','rejected','cancelled'))
    or (old.status = 'approved'          and new.status in ('completed','cancelled'))
  ) then
    raise exception 'Invalid status transition % -> %', old.status, new.status;
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger booking_guard_update before update on public.booking_requests
  for each row execute function public.booking_guard_update();

create table public.approval_steps (
  id               uuid primary key default gen_random_uuid(),
  request_id       uuid not null references public.booking_requests(id) on delete cascade,
  stage_order      int  not null,
  stage_name       text not null,
  authority_label  text not null default '',
  approver_role    text not null check (approver_role in ('edc_admin','dean_admin','super_admin')),
  status           text not null default 'pending'
    check (status in ('pending','approved','rejected','skipped','cancelled')),
  decided_by       uuid references public.profiles(id),
  decided_at       timestamptz,
  reason           text,
  unique (request_id, stage_order)
);
create index approval_steps_req_idx on public.approval_steps (request_id);

create table public.audit_logs (
  id           bigint generated always as identity primary key,
  actor_id     uuid references public.profiles(id) on delete set null,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  details      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
create index audit_entity_idx  on public.audit_logs (entity_id);
create index audit_created_idx on public.audit_logs (created_at desc);

create table public.receipts (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null unique references public.booking_requests(id) on delete cascade,
  receipt_no  text not null unique,
  breakdown   jsonb not null,
  total       numeric(12,2),
  issued_at   timestamptz not null default now(),
  issued_by   uuid references public.profiles(id)
);

create table public.payments (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references public.booking_requests(id) on delete cascade,
  receipt_id  uuid not null references public.receipts(id) on delete cascade,
  amount      numeric(12,2) not null check (amount >= 0),
  method      text not null check (method in ('upi','card','net_banking','cash')),
  status      text not null check (status in ('simulated_success','simulated_failed')),
  is_simulated boolean not null default true check (is_simulated),
  reference   text not null unique,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);
create index payments_req_idx on public.payments (request_id);
-- At most one successful (simulated) payment per request.
create unique index payments_one_success on public.payments (request_id) where status = 'simulated_success';
comment on table public.payments is 'PROTOTYPE ONLY: every row is a simulation (is_simulated is forced true). No real money moves.';

create table public.notification_logs (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid references public.booking_requests(id) on delete cascade,
  event       text not null,
  recipient   text not null,
  subject     text not null,
  body        text not null,
  mode        text not null check (mode in ('sent','simulated','failed')),
  error       text,
  created_at  timestamptz not null default now()
);
create index notif_req_idx on public.notification_logs (request_id);

-- --------------------------------------------------------- generic triggers
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger notices_touch before update on public.notices
  for each row execute function public.touch_updated_at();
create trigger tariff_touch before update on public.tariff_rules
  for each row execute function public.touch_updated_at();

create or replace function public.audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare rec jsonb;
begin
  if tg_op = 'DELETE' then rec := to_jsonb(old); else rec := to_jsonb(new); end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), lower(tg_table_name) || '.' || lower(tg_op), tg_table_name,
          case when rec ? 'id' then (rec ->> 'id')::uuid end,
          jsonb_build_object('summary', left(rec::text, 500)));
  return null;
end $$;

create trigger audit_notices after insert or update or delete on public.notices
  for each row execute function public.audit_row_change();
create trigger audit_tariffs after insert or update or delete on public.tariff_rules
  for each row execute function public.audit_row_change();
create trigger audit_workflows after insert or update or delete on public.approval_workflows
  for each row execute function public.audit_row_change();
create trigger audit_profiles after insert or update or delete on public.profiles
  for each row execute function public.audit_row_change();
create trigger audit_role_perms after insert or delete on public.role_permissions
  for each row execute function public.audit_row_change();
create trigger audit_settings after insert or update on public.app_settings
  for each row execute function public.audit_row_change();

-- After a request is created: snapshot its approval stages + audit entry.
create or replace function public.booking_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare first_stage int;
begin
  insert into public.approval_steps (request_id, stage_order, stage_name, authority_label, approver_role)
  select new.id, stage_order, stage_name, authority_label, approver_role
    from public.approval_workflows
   where room_type = new.room_type and is_active
   order by stage_order;
  if not found then
    raise exception 'No approval workflow is configured for % rooms.', new.room_type;
  end if;
  select min(stage_order) into first_stage from public.approval_steps where request_id = new.id;
  update public.booking_requests set current_stage = first_stage where id = new.id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'request.submitted', 'booking_requests', new.id,
          jsonb_build_object('reference', new.reference));
  return null;
end $$;

create trigger booking_after_insert after insert on public.booking_requests
  for each row execute function public.booking_after_insert();
