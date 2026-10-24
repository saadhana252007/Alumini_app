-- Server-side business rules (security definer). The Flutter app can only
-- change approval state by calling these; direct UPDATEs are blocked by RLS.

create or replace function public.issue_receipt(req public.booking_requests, who uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare calc jsonb; rid uuid;
begin
  calc := public.calculate_charges(req.visitor_category, req.visitor_sub_category,
            req.room_type, req.num_rooms, req.arrival_at, req.departure_at);
  insert into public.receipts (request_id, receipt_no, breakdown, total, issued_by)
  values (req.id,
          'RCPT-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.receipt_no_seq')::text, 6, '0'),
          calc, (calc ->> 'total')::numeric, who)
  returning id into rid;
  return rid;
end $$;

create or replace function public.decide_request(
  p_request_id   uuid,
  p_decision     text,
  p_reason       text default null,
  p_room_no      text default null,
  p_availability text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me   public.profiles;
  req  public.booking_requests;
  stp  public.approval_steps;
  nxt  int;
  new_status text;
begin
  select * into me from public.profiles where id = auth.uid() and is_active;
  if me.id is null then
    raise exception 'Not authorised.' using errcode = '42501';
  end if;
  if not public.has_permission('request.decide') then
    raise exception 'You do not have permission to approve or reject requests.' using errcode = '42501';
  end if;
  if p_decision not in ('approve','reject') then
    raise exception 'Invalid decision.';
  end if;
  if p_availability is not null and p_availability not in ('available','not_available') then
    raise exception 'Invalid availability value.';
  end if;

  -- Row lock => two simultaneous approvals cannot both succeed.
  select * into req from public.booking_requests where id = p_request_id for update;
  if req.id is null then raise exception 'Request not found.'; end if;
  if req.status not in ('pending','awaiting_approval') then
    raise exception 'This request is already %.', replace(req.status, '_', ' ');
  end if;

  select * into stp from public.approval_steps
   where request_id = p_request_id and stage_order = req.current_stage and status = 'pending'
   for update;
  if stp.id is null then raise exception 'No pending approval stage for this request.'; end if;
  if stp.approver_role <> me.role then
    raise exception 'This stage must be decided by the % role.', replace(stp.approver_role, '_', ' ')
      using errcode = '42501';
  end if;

  if p_decision = 'reject' then
    if char_length(trim(coalesce(p_reason, ''))) < 3 then
      raise exception 'A rejection reason is required.';
    end if;
    update public.approval_steps
       set status = 'rejected', decided_by = me.id, decided_at = now(), reason = trim(p_reason)
     where id = stp.id;
    update public.approval_steps set status = 'skipped'
     where request_id = req.id and status = 'pending';
    update public.booking_requests
       set status = 'rejected', rejection_reason = trim(p_reason)
     where id = req.id;
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (me.id, 'request.rejected', 'booking_requests', req.id,
            jsonb_build_object('reference', req.reference, 'stage', stp.stage_order, 'reason', trim(p_reason)));
    return jsonb_build_object('status', 'rejected');
  end if;

  -- approve: record office-use fields if supplied
  update public.booking_requests
     set availability     = coalesce(p_availability, availability),
         allotted_room_no = coalesce(nullif(trim(p_room_no), ''), allotted_room_no)
   where id = req.id
   returning * into req;

  if req.availability is distinct from 'available' then
    raise exception 'Mark the room as Available before approving.';
  end if;

  select min(stage_order) into nxt from public.approval_steps
   where request_id = req.id and status = 'pending' and stage_order > stp.stage_order;

  if nxt is null and req.allotted_room_no is null then
    raise exception 'Enter the suite / room number before final approval.';
  end if;

  update public.approval_steps
     set status = 'approved', decided_by = me.id, decided_at = now(), reason = nullif(trim(p_reason), '')
   where id = stp.id;

  if nxt is null then
    new_status := 'approved';
    update public.booking_requests set status = 'approved' where id = req.id;
    perform public.issue_receipt(req, me.id);
  else
    new_status := 'awaiting_approval';
    update public.booking_requests set status = 'awaiting_approval', current_stage = nxt where id = req.id;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (me.id, 'request.approved', 'booking_requests', req.id,
          jsonb_build_object('reference', req.reference, 'stage', stp.stage_order, 'final', nxt is null));
  return jsonb_build_object('status', new_status);
end $$;

create or replace function public.set_request_status(
  p_request_id uuid, p_new_status text, p_reason text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare req public.booking_requests; me uuid := auth.uid();
begin
  if not public.has_permission('request.manage') then
    raise exception 'You do not have permission to cancel or complete bookings.' using errcode = '42501';
  end if;
  if p_new_status not in ('cancelled','completed') then
    raise exception 'Only cancel or complete is allowed here.';
  end if;
  select * into req from public.booking_requests where id = p_request_id for update;
  if req.id is null then raise exception 'Request not found.'; end if;
  if p_new_status = 'cancelled' and char_length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'A cancellation reason is required.';
  end if;

  -- the guard trigger rejects invalid transitions
  update public.booking_requests
     set status = p_new_status,
         rejection_reason = case when p_new_status = 'cancelled' then trim(p_reason) else rejection_reason end
   where id = req.id;
  if p_new_status = 'cancelled' then
    update public.approval_steps set status = 'cancelled'
     where request_id = req.id and status = 'pending';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (me, 'request.' || p_new_status, 'booking_requests', req.id,
          jsonb_build_object('reference', req.reference, 'reason', p_reason));
end $$;

create or replace function public.simulate_payment(
  p_request_id uuid, p_method text, p_success boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare req public.booking_requests; rc public.receipts; pid uuid; ref text;
begin
  if not public.has_permission('payment.simulate') then
    raise exception 'You do not have permission to simulate payments.' using errcode = '42501';
  end if;
  select * into req from public.booking_requests where id = p_request_id for update;
  if req.id is null then raise exception 'Request not found.'; end if;
  if req.status not in ('approved','completed') then
    raise exception 'Payment can only be simulated for approved bookings.';
  end if;
  select * into rc from public.receipts where request_id = req.id;
  if rc.id is null or rc.total is null then
    raise exception 'The amount is not yet determined; a receipt total is required.';
  end if;
  if rc.total <= 0 then raise exception 'Nothing to pay for this booking.'; end if;
  if exists (select 1 from public.payments where request_id = req.id and status = 'simulated_success') then
    raise exception 'A simulated payment has already been recorded for this booking.';
  end if;

  ref := 'SIM-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));
  insert into public.payments (request_id, receipt_id, amount, method, status, reference, created_by)
  values (req.id, rc.id, rc.total, p_method,
          case when p_success then 'simulated_success' else 'simulated_failed' end, ref, auth.uid())
  returning id into pid;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'payment.simulated', 'booking_requests', req.id,
          jsonb_build_object('reference', ref, 'success', p_success, 'simulated', true));
  return pid;
end $$;

-- Dashboard counters; runs with the caller's rights so RLS applies.
create or replace function public.dashboard_stats() returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'published_notices', (select count(*) from public.notices
        where status = 'published' and publish_date <= current_date
          and (expiry_date is null or expiry_date >= current_date)),
    'pending',   (select count(*) from public.booking_requests where status in ('pending','awaiting_approval')),
    'approved',  (select count(*) from public.booking_requests where status = 'approved'),
    'rejected',  (select count(*) from public.booking_requests where status = 'rejected'),
    'completed', (select count(*) from public.booking_requests where status = 'completed'),
    'upcoming_arrivals', (select count(*) from public.booking_requests
        where status = 'approved' and arrival_at >= now() and arrival_at < now() + interval '7 days'),
    'awaiting_my_decision', (select count(*)
        from public.approval_steps s
        join public.booking_requests r on r.id = s.request_id and r.current_stage = s.stage_order
       where s.status = 'pending' and r.status in ('pending','awaiting_approval')
         and s.approver_role = public.current_role_name())
  );
$$;

-- Exports: re-check report.export and return only register columns
-- (no phone, e-mail or address).
create or replace function public.export_booking_register(
  p_from date default null, p_to date default null,
  p_status text default null, p_category text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.has_permission('report.export') then
    raise exception 'You do not have permission to export reports.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.arrival_at), '[]'::jsonb) into result
  from (
    select r.reference, r.visitor_name, r.organization, r.visitor_category, r.visitor_sub_category,
           r.room_type, r.num_rooms, r.persons_lodging, r.arrival_at, r.departure_at, r.status,
           r.allotted_room_no,
           coalesce(rc.total, r.estimated_amount) as amount,
           (select p.status from public.payments p where p.request_id = r.id
             order by p.created_at desc limit 1) as payment_status
      from public.booking_requests r
      left join public.receipts rc on rc.request_id = r.id
     where (p_from is null or r.arrival_at::date >= p_from)
       and (p_to   is null or r.arrival_at::date <= p_to)
       and (p_status   is null or r.status = p_status)
       and (p_category is null or r.visitor_category = p_category)
  ) t;
  insert into public.audit_logs (actor_id, action, entity_type, details)
  values (auth.uid(), 'report.exported', 'report',
          jsonb_build_object('report', 'booking_register', 'rows', jsonb_array_length(result)));
  return result;
end $$;

create or replace function public.export_approval_report(
  p_from date default null, p_to date default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.has_permission('report.export') then
    raise exception 'You do not have permission to export reports.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(t) order by t.reference, t.stage_order), '[]'::jsonb) into result
  from (
    select r.reference, r.visitor_name, r.room_type, s.stage_order, s.stage_name, s.authority_label,
           s.status as step_status, pr.full_name as decided_by, s.decided_at, s.reason
      from public.approval_steps s
      join public.booking_requests r on r.id = s.request_id
      left join public.profiles pr on pr.id = s.decided_by
     where s.status in ('approved','rejected')
       and (p_from is null or s.decided_at::date >= p_from)
       and (p_to   is null or s.decided_at::date <= p_to)
  ) t;
  insert into public.audit_logs (actor_id, action, entity_type, details)
  values (auth.uid(), 'report.exported', 'report',
          jsonb_build_object('report', 'approval_history', 'rows', jsonb_array_length(result)));
  return result;
end $$;

-- Lock RPCs to signed-in users.
do $$
declare f text;
begin
  foreach f in array array[
    'decide_request(uuid,text,text,text,text)',
    'set_request_status(uuid,text,text)',
    'simulate_payment(uuid,text,boolean)',
    'export_booking_register(date,date,text,text)',
    'export_approval_report(date,date)',
    'issue_receipt(public.booking_requests,uuid)',
    'dashboard_stats()'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
  end loop;
end $$;
grant execute on function public.decide_request(uuid,text,text,text,text) to authenticated;
grant execute on function public.set_request_status(uuid,text,text) to authenticated;
grant execute on function public.simulate_payment(uuid,text,boolean) to authenticated;
grant execute on function public.export_booking_register(date,date,text,text) to authenticated;
grant execute on function public.export_approval_report(date,date) to authenticated;
grant execute on function public.dashboard_stats() to authenticated;
