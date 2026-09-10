-- ==============================================================================
-- MIGRATION: 20260911_user_avatar_and_settings.sql
-- ==============================================================================
-- 1. Añadir columnas y máquina de estados para Avatar en public.profiles
-- 2. Configurar bucket 'avatars' en Supabase Storage con políticas RLS
-- ==============================================================================

-- 1. Alteraciones en public.profiles
alter table public.profiles
  add column if not exists avatar_type text not null default 'initials'
    check (avatar_type in ('initials', 'icon', 'image')),
  add column if not exists avatar_url text,
  add column if not exists avatar_icon text,
  add column if not exists avatar_bg_color text;

-- Restricción de consistencia de estados para evitar estados ambiguos o corruptos
alter table public.profiles drop constraint if exists chk_avatar_state;
alter table public.profiles add constraint chk_avatar_state check (
  (avatar_type = 'initials') or
  (avatar_type = 'icon' and avatar_icon is not null and avatar_bg_color is not null and avatar_url is null) or
  (avatar_type = 'image' and avatar_url is not null and avatar_icon is null and avatar_bg_color is null)
);

-- 2. Aprovisionar bucket de Storage 'avatars' (público para lectura CDN)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Políticas de seguridad para storage.objects en el bucket 'avatars'
-- (Nota: storage.objects ya tiene RLS habilitado por defecto en Supabase)
drop policy if exists "Los avatares son de lectura pública" on storage.objects;
create policy "Los avatares son de lectura pública"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "Los usuarios autenticados pueden subir su propio avatar" on storage.objects;
create policy "Los usuarios autenticados pueden subir su propio avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Los usuarios autenticados pueden actualizar su propio avatar" on storage.objects;
create policy "Los usuarios autenticados pueden actualizar su propio avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Los usuarios autenticados pueden eliminar su propio avatar" on storage.objects;
create policy "Los usuarios autenticados pueden eliminar su propio avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );
