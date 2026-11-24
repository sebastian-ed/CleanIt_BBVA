-- Ejecutar una vez en el proyecto BBVA. No elimina datos existentes.
-- Las sesiones anónimas de Supabase Auth tienen rol SQL authenticated.
-- Se les permite escribir únicamente sus propias nuevas fotografías, nunca leerlas.
drop policy if exists bbva_photo_read on public.bbva_photos;
create policy bbva_photo_read on public.bbva_photos for select to authenticated using(public.bbva_role()='supervisor');
drop policy if exists bbva_photo_insert on public.bbva_photos;
create policy bbva_photo_insert on public.bbva_photos for insert to authenticated with check(owner=auth.uid() and (public.bbva_role() in ('operario','supervisor') or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)) and split_part(path,'/',1)=auth.uid()::text and path=auth.uid()::text||'/'||day::text||'/'||id::text||'.jpg' and status='guardada');
drop policy if exists bbva_storage_upload on storage.objects;
create policy bbva_storage_upload on storage.objects for insert to authenticated with check(bucket_id='bbva-photos' and (public.bbva_role() in ('operario','supervisor') or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)) and (storage.foldername(name))[1]=auth.uid()::text and lower(storage.extension(name))='jpg');
drop policy if exists bbva_storage_read on storage.objects;
create policy bbva_storage_read on storage.objects for select to authenticated using(bucket_id='bbva-photos' and public.bbva_role()='supervisor');
update storage.buckets set public=false,file_size_limit=10485760,allowed_mime_types=array['image/jpeg'] where id='bbva-photos';
-- Un borrador automático jamás reemplaza una revisión confirmada. La operación
-- y el estado de la foto se guardan juntos. Solo servicio backend.
create or replace function public.bbva_save_ocr_v6(p_day date,p_photo uuid,p_rows jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(hashtext('bbva:'||p_day::text));
  if p_photo is distinct from (select id from public.bbva_photos where day=p_day and moment='cierre' order by created_at desc,id desc limit 1) then raise exception 'Hay un cierre más reciente'; end if;
  if exists(select 1 from public.bbva_days where day=p_day and (reviewed or warnings like 'Revisión manual%' or warnings like 'Borrador manual%')) then raise exception 'Hay una revisión del supervisor; requiere intervención manual'; end if;
  insert into public.bbva_days(day,rows,photo_id,reviewed,warnings,updated_at) values(p_day,p_rows,p_photo,false,'OCR automático: verificar todas las filas contra la foto.',now()) on conflict(day) do update set rows=excluded.rows,photo_id=excluded.photo_id,reviewed=false,warnings=excluded.warnings,updated_at=now();
  update public.bbva_photos set status='leida' where id=p_photo;
  return true;
end $$;
revoke all on function public.bbva_save_ocr_v6(date,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.bbva_save_ocr_v6(date,uuid,jsonb) to service_role;
create or replace function public.bbva_save_review_v6(p_day date,p_photo uuid,p_rows jsonb,p_price numeric,p_reviewed boolean)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if public.bbva_role() is distinct from 'supervisor' then raise exception 'Sin permiso'; end if;
  if p_price is null or p_price<0 or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows)>500 then raise exception 'Datos inválidos'; end if;
  perform pg_advisory_xact_lock(hashtext('bbva:'||p_day::text));
  if p_photo is distinct from (select id from public.bbva_photos where day=p_day and moment='cierre' order by created_at desc,id desc limit 1) then raise exception 'Hay un cierre más reciente; actualizá'; end if;
  insert into public.bbva_days(day,rows,price,reviewed,photo_id,warnings,updated_at) values(p_day,p_rows,p_price,p_reviewed,p_photo,case when p_reviewed then 'Revisión manual' else 'Borrador manual: pendiente de confirmar' end,now()) on conflict(day) do update set rows=excluded.rows,price=excluded.price,reviewed=excluded.reviewed,photo_id=excluded.photo_id,warnings=excluded.warnings,updated_at=now();
  update public.bbva_photos set status=case when p_reviewed then 'confirmada' else 'leida' end where id=p_photo;
  return true;
end $$;
revoke all on function public.bbva_save_review_v6(date,uuid,jsonb,numeric,boolean) from public,anon;
grant execute on function public.bbva_save_review_v6(date,uuid,jsonb,numeric,boolean) to authenticated;
