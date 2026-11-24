-- Ejecutar en SQL Editor. No modifica tablas de insumos.
create table if not exists public.bbva_roles(user_id uuid primary key references auth.users(id), role text not null check(role in ('operario','supervisor')));
create table if not exists public.bbva_photos(id uuid primary key default gen_random_uuid(), day date not null, moment text not null check(moment in ('inicio','cierre')), path text not null unique, owner uuid not null default auth.uid(), created_at timestamptz default now(), status text not null default 'guardada');
create table if not exists public.bbva_days(day date primary key, rows jsonb not null default '[]', price numeric not null default 14656 check(price>=0), reviewed boolean default false, warnings text default '', photo_id uuid references public.bbva_photos(id), updated_at timestamptz default now());
create or replace function public.bbva_role() returns text language sql stable security definer set search_path=public as $$ select role from public.bbva_roles where user_id=auth.uid() $$;
alter table public.bbva_roles enable row level security;
alter table public.bbva_photos enable row level security;
alter table public.bbva_days enable row level security;
create policy bbva_own_role on public.bbva_roles for select to authenticated using(user_id=auth.uid());
create policy bbva_photo_read on public.bbva_photos for select to authenticated using(owner=auth.uid() or public.bbva_role()='supervisor');
create policy bbva_photo_insert on public.bbva_photos for insert to authenticated with check(owner=auth.uid() and public.bbva_role() in ('operario','supervisor') and split_part(path,'/',1)=auth.uid()::text);
create policy bbva_day_read on public.bbva_days for select to authenticated using(public.bbva_role()='supervisor');
create policy bbva_day_write on public.bbva_days for all to authenticated using(public.bbva_role()='supervisor') with check(public.bbva_role()='supervisor');
insert into storage.buckets(id,name,public) values('bbva-photos','bbva-photos',false) on conflict(id) do nothing;
create policy bbva_storage_upload on storage.objects for insert to authenticated with check(bucket_id='bbva-photos' and public.bbva_role() in ('operario','supervisor') and (storage.foldername(name))[1]=auth.uid()::text);
create policy bbva_storage_read on storage.objects for select to authenticated using(bucket_id='bbva-photos' and (public.bbva_role()='supervisor' or (storage.foldername(name))[1]=auth.uid()::text));
-- Crear usuarios desde Authentication > Users y asignar rol:
-- insert into public.bbva_roles values ('UUID_DEL_USUARIO','supervisor');
