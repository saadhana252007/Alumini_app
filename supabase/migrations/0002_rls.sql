-- Row Level Security. Every table is locked down; access flows through
-- has_permission() and the security-definer RPCs in 0003.

alter table public.profiles            enable row level security;
alter table public.role_permissions    enable row level security;
alter table public.app_settings        enable row level security;
alter table public.notices             enable row level security;
alter table public.tariff_rules        enable row level security;
alter table public.approval_workflows  enable row level security;
alter table public.booking_requests    enable row level security;
alter table public.approval_steps      enable row level security;
alter table public.audit_logs          enable row level security;
alter table public.receipts            enable row level security;
alter table public.payments            enable row level security;
alter table public.notification_logs   enable row level security;

-- profiles: no INSERT/DELETE policy => only service role (Edge Function / script).
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_active_admin());
create policy profiles_update on public.profiles for update to authenticated
  using (public.has_permission('admin.manage') and id <> auth.uid())
  with check (public.has_permission('admin.manage'));

create policy rp_select on public.role_permissions for select to authenticated
  using (public.is_active_admin());
create policy rp_insert on public.role_permissions for insert to authenticated
  with check (public.has_permission('admin.manage'));
create policy rp_delete on public.role_permissions for delete to authenticated
  using (public.has_permission('admin.manage')
         and not (role = 'super_admin' and permission = 'admin.manage'));

create policy settings_select on public.app_settings for select to authenticated
  using (public.is_active_admin());
create policy settings_insert on public.app_settings for insert to authenticated
  with check (public.has_permission('tariff.manage'));
create policy settings_update on public.app_settings for update to authenticated
  using (public.has_permission('tariff.manage'))
  with check (public.has_permission('tariff.manage'));

create policy notices_select on public.notices for select to authenticated
  using (public.has_permission('notice.view'));
create policy notices_insert on public.notices for insert to authenticated
  with check (public.has_permission('notice.manage') and created_by = auth.uid());
create policy notices_update on public.notices for update to authenticated
  using (public.has_permission('notice.manage'))
  with check (public.has_permission('notice.manage'));
create policy notices_delete on public.notices for delete to authenticated
  using (public.has_permission('notice.manage'));

create policy tariff_select on public.tariff_rules for select to authenticated
  using (public.is_active_admin());
create policy tariff_update on public.tariff_rules for update to authenticated
  using (public.has_permission('tariff.manage'))
  with check (public.has_permission('tariff.manage'));
create policy tariff_insert on public.tariff_rules for insert to authenticated
  with check (public.has_permission('tariff.manage'));

create policy wf_select on public.approval_workflows for select to authenticated
  using (public.is_active_admin());
create policy wf_insert on public.approval_workflows for insert to authenticated
  with check (public.has_permission('config.manage'));
create policy wf_update on public.approval_workflows for update to authenticated
  using (public.has_permission('config.manage'))
  with check (public.has_permission('config.manage'));
create policy wf_delete on public.approval_workflows for delete to authenticated
  using (public.has_permission('config.manage'));

-- Booking requests: read with request.view, create with request.create.
-- NO update/delete policy: all changes go through decide_request / set_request_status.
create policy br_select on public.booking_requests for select to authenticated
  using (public.has_permission('request.view'));
create policy br_insert on public.booking_requests for insert to authenticated
  with check (public.has_permission('request.create') and created_by = auth.uid());

create policy steps_select on public.approval_steps for select to authenticated
  using (public.has_permission('request.view'));

create policy audit_select on public.audit_logs for select to authenticated
  using (public.has_permission('report.view'));

create policy receipts_select on public.receipts for select to authenticated
  using (public.has_permission('receipt.view'));
create policy payments_select on public.payments for select to authenticated
  using (public.has_permission('receipt.view'));

create policy notif_select on public.notification_logs for select to authenticated
  using (public.has_permission('request.view'));

-- Nothing is readable or writable by the anonymous role.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
