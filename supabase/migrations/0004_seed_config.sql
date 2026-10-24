-- Initial configuration. This is prototype CONFIG data (tariffs, roles,
-- workflow), not application records. Super Admin can change all of it.

insert into public.role_permissions (role, permission) values
  -- EDC Admin: reviews and records office decisions
  ('edc_admin','notice.view'),('edc_admin','request.view'),('edc_admin','request.create'),
  ('edc_admin','request.decide'),('edc_admin','request.manage'),('edc_admin','report.view'),
  ('edc_admin','report.export'),('edc_admin','receipt.view'),('edc_admin','payment.simulate'),
  -- Dean Admin: notices + oversight; decides at the approval stage assigned to it
  ('dean_admin','notice.view'),('dean_admin','notice.manage'),('dean_admin','request.view'),
  ('dean_admin','request.decide'),('dean_admin','report.view'),('dean_admin','report.export'),
  ('dean_admin','receipt.view'),
  -- Super Admin: configuration and administration (no day-to-day approvals by default)
  ('super_admin','notice.view'),('super_admin','notice.manage'),('super_admin','request.view'),
  ('super_admin','report.view'),('super_admin','report.export'),('super_admin','receipt.view'),
  ('super_admin','tariff.manage'),('super_admin','config.manage'),('super_admin','admin.manage')
on conflict do nothing;

insert into public.app_settings (key, value) values ('gst_percent', '0'::jsonb)
on conflict (key) do nothing;

-- Tariff from the EDC form, Section II. "plus admissible GST" has no rate in the
-- form, so GST is the configurable setting above (0% until confirmed).
insert into public.tariff_rules (visitor_category, sub_category, room_type, rate, billing_unit, note) values
  ('A','', 'standard', 0,    'free',     'Institute guests - free boarding and lodging'),
  ('A','', 'suite',    0,    'free',     'Institute guests - free boarding and lodging'),
  ('B','', 'standard', 600,  'per_day',  'Concession rate'),
  ('B','', 'suite',    950,  'per_day',  'Concession rate'),
  ('C','', 'standard', 1000, 'per_day',  'Official rate'),
  ('C','', 'suite',    1500, 'per_day',  'Official rate'),
  ('D','', 'standard', 1200, 'per_day',  'Full rate'),
  ('D','', 'suite',    2000, 'per_day',  'Full rate'),
  ('E','a','suite',    3000, 'per_day',  'Foreign guest / participants'),
  ('E','a','standard', null, 'unspecified', 'Form lists no standard-room rate for foreign guests - to be confirmed'),
  ('E','b','standard', 4000, 'per_month','Chair / Visiting Professor (approved by Director)'),
  ('E','b','suite',    5000, 'per_month','Chair / Visiting Professor (approved by Director)'),
  ('E','c','standard', null, 'as_applicable','Quarters-entitled employees pay the applicable license fee'),
  ('E','c','suite',    null, 'as_applicable','Quarters-entitled employees pay the applicable license fee')
on conflict do nothing;

-- Approval authority per room type. The form says: suites -> Director / Dy Director,
-- other rooms -> Dean (Administration) / Assoc. Dean (Administration), with the office
-- (Officer-In-Charge, EDC) recording availability first. The app has no Director
-- role, so the suite final stage is delegated to Dean Admin as a PLACEHOLDER.
-- Edit under Administration > Approval workflow after the institute confirms.
insert into public.approval_workflows (room_type, stage_order, stage_name, authority_label, approver_role) values
  ('standard',1,'Office verification','Officer-In-Charge, EDC','edc_admin'),
  ('standard',2,'Final approval','Dean (Administration) / Assoc. Dean (Administration)','dean_admin'),
  ('suite',   1,'Office verification','Officer-In-Charge, EDC','edc_admin'),
  ('suite',   2,'Final approval','Director / Deputy Director (placeholder: Dean Admin acts as delegate - confirm)','dean_admin')
on conflict do nothing;
