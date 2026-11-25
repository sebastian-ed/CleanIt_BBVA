BEGIN;
alter table public.bbva_photos add column if not exists operator_name text;
create table if not exists public.bbva_audit (
 id bigint generated always as identity primary key, at timestamptz not null default now(), actor uuid, actor_email text, actor_label text, device text, action text not null, day date, detail jsonb not null default '{}'::jsonb
);
alter table public.bbva_audit enable row level security;
revoke all on public.bbva_audit from anon,authenticated;
grant select on public.bbva_audit to authenticated;
drop policy if exists bbva_audit_supervisor on public.bbva_audit;
create policy bbva_audit_supervisor on public.bbva_audit for select to authenticated using(public.bbva_role()='supervisor');
create or replace function public.bbva_audit_write(p_action text,p_day date,p_detail jsonb,p_label text default null) returns void language plpgsql security definer set search_path=public as $$
declare h jsonb:=coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb; j jsonb:=coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb; a uuid:=auth.uid(); em text:=j->>'email'; dev text:=h->>'user-agent';
begin
 if j->>'role'='service_role' then
  a:=nullif(h->>'x-bbva-actor','')::uuid; em:=nullif(h->>'x-bbva-email',''); dev:=coalesce(h->>'x-bbva-device',dev);
 end if;
 insert into public.bbva_audit(actor,actor_email,actor_label,device,action,day,detail) values(a,em,coalesce(nullif(p_label,''),em,case when a is null then 'Sistema / backend' else 'Sesión sin nombre' end),left(dev,500),p_action,p_day,coalesce(p_detail,'{}'));
end $$;
revoke all on function public.bbva_audit_write(text,date,jsonb,text) from public,anon,authenticated;
create or replace function public.bbva_audit_trigger() returns trigger language plpgsql security definer set search_path=public as $$
declare b jsonb; n jsonb; v jsonb; label text; act text;
begin
 if TG_OP<>'INSERT' then b:=to_jsonb(OLD); end if;
 if TG_OP<>'DELETE' then n:=to_jsonb(NEW); end if;
 v:=coalesce(n,b); label:=case when TG_TABLE_NAME='bbva_photos' and TG_OP='INSERT' then v->>'operator_name' else null end;
 act:=case when TG_TABLE_NAME='bbva_photos' then case TG_OP when 'INSERT' then 'FOTO_CARGADA' when 'DELETE' then 'FOTO_ARCHIVADA' else 'FOTO_ACTUALIZADA' end else case TG_OP when 'INSERT' then 'DIA_CREADO' when 'DELETE' then 'DIA_ARCHIVADO' else case when n->>'reviewed'='true' then 'DIA_CONFIRMADO' else 'DIA_EDITADO' end end end;
 if b is distinct from n then perform public.bbva_audit_write(act,(v->>'day')::date,jsonb_build_object('antes',b,'despues',n),label); end if;
 if TG_OP='DELETE' then return OLD; end if; return NEW;
end $$;
revoke all on function public.bbva_audit_trigger() from public,anon,authenticated;
drop trigger if exists bbva_audit_photos on public.bbva_photos;
create trigger bbva_audit_photos after insert or update or delete on public.bbva_photos for each row execute function public.bbva_audit_trigger();
drop trigger if exists bbva_audit_days on public.bbva_days;
create trigger bbva_audit_days after insert or update or delete on public.bbva_days for each row execute function public.bbva_audit_trigger();
create or replace function public.bbva_log_event_v8(p_action text,p_day date default null,p_detail jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or (public.bbva_role() is distinct from 'supervisor' and p_action not in ('OCR_ERROR','OCR_INICIO')) then raise exception 'Sin permiso'; end if;
 if p_action not in ('LOGIN','LOGOUT','CSV_EXPORTADO','OCR_INICIO','OCR_ERROR','GEMINI_INICIO','GEMINI_ERROR','MODELO_CONFIGURADO') then raise exception 'Evento inválido'; end if;
 perform public.bbva_audit_write(p_action,p_day,jsonb_build_object('mensaje',left(coalesce(p_detail->>'mensaje',''),500)),null);
end $$;
revoke all on function public.bbva_log_event_v8(text,date,jsonb) from public,anon;
grant execute on function public.bbva_log_event_v8(text,date,jsonb) to authenticated;
create table if not exists public.bbva_day_archive(id uuid primary key default gen_random_uuid(),day date not null, archived_at timestamptz default now(), archived_by uuid, reason text, snapshot jsonb not null);
alter table public.bbva_day_archive enable row level security;
revoke all on public.bbva_day_archive from anon,authenticated;
grant select on public.bbva_day_archive to authenticated;
drop policy if exists bbva_archive_read on public.bbva_day_archive;
create policy bbva_archive_read on public.bbva_day_archive for select to authenticated using(public.bbva_role()='supervisor');
create or replace function public.bbva_manage_day_v8(p_action text,p_day date,p_target date default null,p_reason text default '') returns boolean language plpgsql security definer set search_path=public as $$
declare snap jsonb;
begin
 if public.bbva_role() is distinct from 'supervisor' then raise exception 'Sin permiso'; end if;
 if p_day is null then raise exception 'Fecha inválida'; end if;
 -- Serializar cambios de fecha y revisión. Bloquear origen/destino en orden.
 perform pg_advisory_xact_lock(hashtext('bbva:'||least(p_day,coalesce(p_target,p_day))::text));
 if p_target is not null and p_target<>p_day then perform pg_advisory_xact_lock(hashtext('bbva:'||greatest(p_day,p_target)::text)); end if;
 if p_action='create' then
  if exists(select 1 from public.bbva_days where day=p_day) or exists(select 1 from public.bbva_photos where day=p_day) then raise exception 'Ya existe ese día'; end if;
  insert into public.bbva_days(day,rows,reviewed,warnings) values(p_day,'[]',false,'Día manual sin foto');
 elsif p_action='move' then
  if p_target is null or p_target=p_day then raise exception 'Fecha destino inválida'; end if;
  if not exists(select 1 from public.bbva_days where day=p_day) and not exists(select 1 from public.bbva_photos where day=p_day) then raise exception 'No existe el día'; end if;
  if exists(select 1 from public.bbva_days where day=p_target) or exists(select 1 from public.bbva_photos where day=p_target) then raise exception 'La fecha destino ya tiene registros'; end if;
  update public.bbva_photos set day=p_target where day=p_day;
  update public.bbva_days set day=p_target,updated_at=now() where day=p_day;
  perform public.bbva_audit_write('FECHA_MODIFICADA',p_day,jsonb_build_object('destino',p_target),null);
 elsif p_action='delete' then
  if not exists(select 1 from public.bbva_days where day=p_day) and not exists(select 1 from public.bbva_photos where day=p_day) then raise exception 'No existe el día'; end if;
  if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Indicá el motivo'; end if;
  select jsonb_build_object('day',(select to_jsonb(d) from public.bbva_days d where day=p_day),'photos',coalesce((select jsonb_agg(to_jsonb(p)) from public.bbva_photos p where day=p_day),'[]')) into snap;
  insert into public.bbva_day_archive(day,archived_by,reason,snapshot) values(p_day,auth.uid(),left(p_reason,500),snap);
  delete from public.bbva_days where day=p_day;
  delete from public.bbva_photos where day=p_day;
  perform public.bbva_audit_write('DIA_ELIMINADO',p_day,jsonb_build_object('motivo',left(p_reason,500)),null);
 else raise exception 'Acción inválida'; end if;
 return true;
end $$;
revoke all on function public.bbva_manage_day_v8(text,date,date,text) from public,anon;
grant execute on function public.bbva_manage_day_v8(text,date,date,text) to authenticated;
create or replace function public.bbva_restore_day_v8(p_id uuid) returns boolean language plpgsql security definer set search_path=public as $$
declare a public.bbva_day_archive%rowtype;
begin
 if public.bbva_role() is distinct from 'supervisor' then raise exception 'Sin permiso'; end if;
 select * into a from public.bbva_day_archive where id=p_id for update;
 if not found then raise exception 'Archivo inexistente'; end if;
 perform pg_advisory_xact_lock(hashtext('bbva:'||a.day::text));
 if exists(select 1 from public.bbva_days where day=a.day) or exists(select 1 from public.bbva_photos where day=a.day) then raise exception 'La fecha ya tiene registros activos'; end if;
 insert into public.bbva_photos select * from jsonb_populate_recordset(null::public.bbva_photos,a.snapshot->'photos');
 if jsonb_typeof(a.snapshot->'day')='object' then insert into public.bbva_days select * from jsonb_populate_record(null::public.bbva_days,a.snapshot->'day'); end if;
 delete from public.bbva_day_archive where id=p_id;
 perform public.bbva_audit_write('DIA_RESTAURADO',a.day,jsonb_build_object('archivo',p_id),null);
 return true;
end $$;
revoke all on function public.bbva_restore_day_v8(uuid) from public,anon;
grant execute on function public.bbva_restore_day_v8(uuid) to authenticated;
-- Manual days are supported by the existing save RPC with p_photo=null.
-- Serialize incoming photo registration with day management.
create or replace function public.bbva_lock_photo_day_v8() returns trigger language plpgsql set search_path=public as $$ begin perform pg_advisory_xact_lock(hashtext('bbva:'||NEW.day::text)); return NEW; end $$;
drop trigger if exists bbva_lock_photo_day on public.bbva_photos;
create trigger bbva_lock_photo_day before insert on public.bbva_photos for each row execute function public.bbva_lock_photo_day_v8();
notify pgrst, 'reload schema';
COMMIT;
