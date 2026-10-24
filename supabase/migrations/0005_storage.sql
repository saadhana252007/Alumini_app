-- Private bucket for notice posters. Reads use short-lived signed URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('notices', 'notices', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy notices_objects_read on storage.objects for select to authenticated
  using (bucket_id = 'notices' and public.has_permission('notice.view'));
create policy notices_objects_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'notices' and public.has_permission('notice.manage'));
create policy notices_objects_update on storage.objects for update to authenticated
  using (bucket_id = 'notices' and public.has_permission('notice.manage'));
create policy notices_objects_delete on storage.objects for delete to authenticated
  using (bucket_id = 'notices' and public.has_permission('notice.manage'));
