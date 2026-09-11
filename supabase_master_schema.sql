-- ==============================================================================
-- MARTHAPP - SUPABASE MASTER SCHEMA
-- ==============================================================================
-- Este script es autocontenido e idempotente.
-- Puedes copiar y pegar todo este contenido directamente en el SQL Editor
-- de tu proyecto de Supabase (Dashboard -> SQL Editor -> New Query -> Run).
--
-- Contenido:
-- 1. Extensiones requeridas
-- 2. Tabla `profiles` + RLS + Triggers de nuevo usuario
-- 3. Tabla `friend_codes` (Códigos de invitación con caducidad exacta de 60s) + RLS
-- 4. Tabla `friend_requests` (Solicitudes y relaciones de amistad) + RLS
-- 5. Funciones RPC:
--    - `create_or_update_friend_code`: registra el código con 60s de validez
--    - `redeem_friend_code`: canjea código, valida expiración, crea solicitud y retorna el username real
-- 6. Configuración de Supabase Realtime (WebSockets para actualización instantánea)
-- ==============================================================================

-- 1. Extensiones
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. TABLA: profiles (Perfiles de Usuario)
-- ------------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_type text not null default 'initials' check (avatar_type in ('initials', 'icon', 'image')),
  avatar_url text,
  avatar_icon text,
  avatar_bg_color text,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint chk_avatar_state check (
    (avatar_type = 'initials') or
    (avatar_type = 'icon' and avatar_icon is not null and avatar_bg_color is not null and avatar_url is null) or
    (avatar_type = 'image' and avatar_url is not null and avatar_icon is null and avatar_bg_color is null)
  )
);

-- Asegurar columnas si la tabla ya existía previamente
alter table public.profiles
  add column if not exists avatar_type text not null default 'initials'
    check (avatar_type in ('initials', 'icon', 'image')),
  add column if not exists avatar_url text,
  add column if not exists avatar_icon text,
  add column if not exists avatar_bg_color text;

alter table public.profiles drop constraint if exists chk_avatar_state;
alter table public.profiles add constraint chk_avatar_state check (
  (avatar_type = 'initials') or
  (avatar_type = 'icon' and avatar_icon is not null and avatar_bg_color is not null and avatar_url is null) or
  (avatar_type = 'image' and avatar_url is not null and avatar_icon is null and avatar_bg_color is null)
);

-- Habilitar Row Level Security (RLS)
alter table public.profiles enable row level security;

-- Políticas RLS para profiles
drop policy if exists "Los perfiles son visibles para todos los usuarios autenticados" on public.profiles;
create policy "Los perfiles son visibles para todos los usuarios autenticados"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Los usuarios pueden insertar su propio perfil" on public.profiles;
create policy "Los usuarios pueden insertar su propio perfil"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Los usuarios pueden actualizar exclusivamente su propio perfil" on public.profiles;
create policy "Los usuarios pueden actualizar exclusivamente su propio perfil"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Trigger para crear automáticamente el perfil y el entorno personal al registrarse en auth.users
create or replace function public.handle_new_user()
returns trigger as $$
declare
  raw_username text;
  v_env_id uuid;
begin
  raw_username := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1)
  );

  if exists (select 1 from public.profiles where lower(username) = lower(raw_username)) then
    raw_username := raw_username || '_' || substr(md5(random()::text), 1, 4);
  end if;

  insert into public.profiles (id, username, updated_at)
  values (new.id, raw_username, now())
  on conflict (id) do update
  set updated_at = now();

  -- Creación automática del entorno personal principal "Mi Espacio"
  insert into public.environments (name, is_personal, created_by, created_at)
  values ('Mi Espacio', true, new.id, now())
  returning id into v_env_id;

  insert into public.environment_members (environment_id, user_id, role, joined_at)
  values (v_env_id, new.id, 'owner', now())
  on conflict (environment_id, user_id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 3. TABLA: friend_codes (Códigos de Amigo con Expiración a los 60 Segundos)
-- ------------------------------------------------------------------------------
create table if not exists public.friend_codes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  code text unique not null,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint unique_user_active_code unique (user_id)
);

-- Habilitar RLS
alter table public.friend_codes enable row level security;

-- Políticas RLS para friend_codes
drop policy if exists "Cualquier usuario autenticado puede consultar códigos activos" on public.friend_codes;
create policy "Cualquier usuario autenticado puede consultar códigos activos"
  on public.friend_codes for select
  to authenticated
  using (true);

drop policy if exists "Los usuarios solo pueden insertar o reemplazar su propio código" on public.friend_codes;
create policy "Los usuarios solo pueden insertar o reemplazar su propio código"
  on public.friend_codes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Los usuarios solo pueden actualizar su propio código" on public.friend_codes;
create policy "Los usuarios solo pueden actualizar su propio código"
  on public.friend_codes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Los usuarios solo pueden borrar su propio código" on public.friend_codes;
create policy "Los usuarios solo pueden borrar su propio código"
  on public.friend_codes for delete
  to authenticated
  using (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 4. TABLA: friend_requests (Solicitudes y Relaciones de Amistad)
-- ------------------------------------------------------------------------------
create table if not exists public.friend_requests (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  status text check (status in ('pending', 'accepted', 'rejected')) default 'pending' not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint unique_friend_request unique (sender_id, receiver_id),
  constraint cannot_friend_self check (sender_id <> receiver_id)
);

-- Habilitar RLS
alter table public.friend_requests enable row level security;

-- Políticas RLS para friend_requests
drop policy if exists "Ver solicitudes donde el usuario sea emisor o receptor" on public.friend_requests;
create policy "Ver solicitudes donde el usuario sea emisor o receptor"
  on public.friend_requests for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Enviar solicitudes solo como emisor" on public.friend_requests;
create policy "Enviar solicitudes solo como emisor"
  on public.friend_requests for insert
  to authenticated
  with check (auth.uid() = sender_id and sender_id <> receiver_id);

drop policy if exists "Actualizar solicitudes donde se participe" on public.friend_requests;
create policy "Actualizar solicitudes donde se participe"
  on public.friend_requests for update
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id)
  with check (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Eliminar solicitud o amistad donde se participe" on public.friend_requests;
create policy "Eliminar solicitud o amistad donde se participe"
  on public.friend_requests for delete
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Índices de aceleración
create index if not exists idx_profiles_username_lower on public.profiles (lower(username));
create index if not exists idx_friend_codes_code on public.friend_codes (code);
create index if not exists idx_friend_codes_expires on public.friend_codes (expires_at);
create index if not exists idx_friend_requests_sender on public.friend_requests (sender_id);
create index if not exists idx_friend_requests_receiver on public.friend_requests (receiver_id);
create index if not exists idx_friend_requests_status on public.friend_requests (status);

-- ------------------------------------------------------------------------------
-- 5. FUNCIONES RPC
-- ------------------------------------------------------------------------------

-- Función: Registrar o actualizar código de amigo temporal (duración: 60s por defecto)
create or replace function public.create_or_update_friend_code(
  p_code text,
  p_duration_seconds int default 60
)
returns jsonb as $$
declare
  v_user_id uuid;
  v_expires_at timestamp with time zone;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_expires_at := now() + (p_duration_seconds || ' seconds')::interval;

  insert into public.friend_codes (user_id, code, expires_at, created_at)
  values (v_user_id, upper(trim(p_code)), v_expires_at, now())
  on conflict (user_id) do update
  set code = excluded.code,
      expires_at = excluded.expires_at,
      created_at = now();

  return jsonb_build_object(
    'success', true,
    'code', upper(trim(p_code)),
    'expires_at', v_expires_at
  );
end;
$$ language plpgsql security definer;

-- Función: Canjear código de amigo, verificar caducidad y generar la invitación en tiempo real
create or replace function public.redeem_friend_code(p_code text)
returns jsonb as $$
declare
  v_code_clean text;
  v_sender_id uuid;
  v_code_record record;
  v_receiver_id uuid;
  v_receiver_profile record;
  v_existing record;
  v_request_id uuid;
begin
  v_sender_id := auth.uid();
  if v_sender_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_code_clean := upper(trim(p_code));

  -- 1. Buscar código y comprobar si está activo y no expirado (< 60s)
  select * into v_code_record
  from public.friend_codes
  where upper(code) = v_code_clean;

  if v_code_record is null then
    raise exception 'El código "%" no existe.', v_code_clean;
  end if;

  if v_code_record.expires_at <= now() then
    raise exception 'El código ha expirado (validez: 60 segundos). Solicita uno nuevo a tu amigo.';
  end if;

  v_receiver_id := v_code_record.user_id;

  -- 2. No permitir canjear el propio código
  if v_sender_id = v_receiver_id then
    raise exception 'No puedes canjear tu propio código de amigo.';
  end if;

  -- 3. Obtener el perfil real del dueño del código
  select * into v_receiver_profile
  from public.profiles
  where id = v_receiver_id;

  if v_receiver_profile is null then
    raise exception 'El perfil del amigo no fue encontrado.';
  end if;

  -- 4. Comprobar si ya existe relación previa entre los dos usuarios
  select * into v_existing
  from public.friend_requests
  where (sender_id = v_sender_id and receiver_id = v_receiver_id)
     or (sender_id = v_receiver_id and receiver_id = v_sender_id);

  if v_existing is not null then
    if v_existing.status = 'accepted' then
      raise exception 'Ya eres amigo de %', v_receiver_profile.username;
    elsif v_existing.status = 'pending' then
      if v_existing.sender_id = v_sender_id then
        raise exception 'Ya tienes una solicitud pendiente enviada a %', v_receiver_profile.username;
      else
        -- El otro usuario ya nos había enviado una solicitud: la aceptamos inmediatamente
        update public.friend_requests
        set status = 'accepted'
        where id = v_existing.id;

        return jsonb_build_object(
          'success', true,
          'status', 'accepted',
          'message', '¡Amistad aceptada con ' || v_receiver_profile.username || '!',
          'friend_id', v_receiver_id,
          'friend_username', v_receiver_profile.username
        );
      end if;
    else
      -- Si estaba rechazada, reabrir como pendiente
      update public.friend_requests
      set status = 'pending',
          sender_id = v_sender_id,
          receiver_id = v_receiver_id,
          created_at = now()
      where id = v_existing.id;

      return jsonb_build_object(
        'success', true,
        'status', 'pending',
        'message', '¡Invitación reenviada a ' || v_receiver_profile.username || '!',
        'friend_id', v_receiver_id,
        'friend_username', v_receiver_profile.username
      );
    end if;
  end if;

  -- 5. Crear la nueva solicitud de amistad entrante para el dueño del código
  insert into public.friend_requests (sender_id, receiver_id, status, created_at)
  values (v_sender_id, v_receiver_id, 'pending', now())
  returning id into v_request_id;

  return jsonb_build_object(
    'success', true,
    'status', 'pending',
    'message', '¡Invitación enviada a ' || v_receiver_profile.username || '!',
    'friend_id', v_receiver_id,
    'friend_username', v_receiver_profile.username,
    'request_id', v_request_id
  );
end;
$$ language plpgsql security definer;

-- Función: Eliminar amistad bidireccional entre el usuario actual y un amigo
create or replace function public.remove_friend(p_friend_id uuid)
returns boolean as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  delete from public.friend_requests
  where (sender_id = v_user_id and receiver_id = p_friend_id)
     or (sender_id = p_friend_id and receiver_id = v_user_id);

  return true;
end;
$$ language plpgsql security definer;

-- ------------------------------------------------------------------------------
-- 6. CONFIGURACIÓN SUPABASE REALTIME (WebSockets)
-- ------------------------------------------------------------------------------
alter table public.profiles replica identity full;
alter table public.friend_codes replica identity full;
alter table public.friend_requests replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.profiles, public.friend_codes, public.friend_requests;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;

-- ------------------------------------------------------------------------------
-- 7. CONFIGURACIÓN SUPABASE STORAGE (Bucket de Avatares)
-- ------------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Políticas de seguridad para storage.objects en el bucket 'avatars'
-- (storage.objects ya tiene RLS habilitado por defecto por Supabase)
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

-- ------------------------------------------------------------------------------
-- 8. GESTIÓN DE ENTORNOS (Workspaces/Environments)
-- ------------------------------------------------------------------------------

-- Tabla environments
create table if not exists public.environments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_personal boolean not null default false,
  created_by uuid references auth.users(id) on delete cascade not null,
  created_at timestamp with time zone default now() not null
);

-- Tabla environment_members
create table if not exists public.environment_members (
  environment_id uuid references public.environments(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text not null check (role in ('owner', 'member')),
  joined_at timestamp with time zone default now() not null,
  primary key (environment_id, user_id)
);

-- Tabla environment_invitations
create table if not exists public.environment_invitations (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid references public.environments(id) on delete cascade not null,
  sender_id uuid references auth.users(id) on delete cascade not null,
  receiver_id uuid references auth.users(id) on delete cascade not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamp with time zone default now() not null
);

-- Índice único condicional: 1 invitación pendiente por entorno y receptor
create unique index if not exists idx_unique_pending_invitation 
  on public.environment_invitations (environment_id, receiver_id) 
  where status = 'pending';

-- Índice único condicional: garantiza como máximo 1 entorno personal por usuario (anti-race condition)
create unique index if not exists idx_unique_personal_environment
  on public.environments (created_by)
  where is_personal = true;

create index if not exists idx_environments_created_by on public.environments (created_by);
create index if not exists idx_environments_is_personal on public.environments (is_personal);
create index if not exists idx_env_members_user on public.environment_members (user_id);
create index if not exists idx_env_invitations_receiver on public.environment_invitations (receiver_id);
create index if not exists idx_env_invitations_status on public.environment_invitations (status);

-- RLS: Habilitación y Políticas no recursivas
alter table public.environments enable row level security;
alter table public.environment_members enable row level security;
alter table public.environment_invitations enable row level security;

-- environment_members (lectura directa y O(1) para evitar recursión RLS)
drop policy if exists "Los miembros pueden consultar sus propias membresías" on public.environment_members;
create policy "Los miembros pueden consultar sus propias membresías"
  on public.environment_members for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Los usuarios pueden insertar o unirse a membresías" on public.environment_members;
create policy "Los usuarios pueden insertar o unirse a membresías"
  on public.environment_members for insert
  to authenticated
  with check (
    auth.uid() = user_id or
    exists (
      select 1 from public.environments
      where id = environment_members.environment_id and created_by = auth.uid()
    )
  );

drop policy if exists "Los miembros pueden abandonar o el owner expulsar" on public.environment_members;
create policy "Los miembros pueden abandonar o el owner expulsar"
  on public.environment_members for delete
  to authenticated
  using (
    auth.uid() = user_id or
    exists (
      select 1 from public.environments
      where id = environment_members.environment_id and created_by = auth.uid()
    )
  );

-- environments (valida membresía usando EXISTS sobre environment_members)
drop policy if exists "Los usuarios pueden ver entornos donde son miembros" on public.environments;
create policy "Los usuarios pueden ver entornos donde son miembros"
  on public.environments for select
  to authenticated
  using (
    exists (
      select 1 from public.environment_members
      where environment_members.environment_id = environments.id
        and environment_members.user_id = auth.uid()
    )
  );

drop policy if exists "Los usuarios pueden crear entornos como creadores" on public.environments;
create policy "Los usuarios pueden crear entornos como creadores"
  on public.environments for insert
  to authenticated
  with check (auth.uid() = created_by);

drop policy if exists "Los owners pueden actualizar sus entornos" on public.environments;
create policy "Los owners pueden actualizar sus entornos"
  on public.environments for update
  to authenticated
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

drop policy if exists "Los owners pueden eliminar sus entornos" on public.environments;
create policy "Los owners pueden eliminar sus entornos"
  on public.environments for delete
  to authenticated
  using (auth.uid() = created_by);

-- environment_invitations
drop policy if exists "Ver invitaciones donde se sea emisor o receptor" on public.environment_invitations;
create policy "Ver invitaciones donde se sea emisor o receptor"
  on public.environment_invitations for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Enviar invitaciones a entornos donde se participe" on public.environment_invitations;
create policy "Enviar invitaciones a entornos donde se participe"
  on public.environment_invitations for insert
  to authenticated
  with check (
    auth.uid() = sender_id and
    exists (
      select 1 from public.environments
      where id = environment_invitations.environment_id
        and is_personal = false
    ) and
    exists (
      select 1 from public.environment_members
      where environment_id = environment_invitations.environment_id
        and user_id = auth.uid()
    )
  );

drop policy if exists "Actualizar estado de invitaciones correspondientes" on public.environment_invitations;
create policy "Actualizar estado de invitaciones correspondientes"
  on public.environment_invitations for update
  to authenticated
  using (auth.uid() = receiver_id or auth.uid() = sender_id)
  with check (auth.uid() = receiver_id or auth.uid() = sender_id);

drop policy if exists "Eliminar invitaciones propias" on public.environment_invitations;
create policy "Eliminar invitaciones propias"
  on public.environment_invitations for delete
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- RPC 1: create_environment
create or replace function public.create_environment(p_name text)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_name_clean text;
  v_new_env public.environments%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  v_name_clean := trim(p_name);
  if length(v_name_clean) < 3 then
    raise exception 'El nombre del entorno debe tener al menos 3 caracteres';
  end if;

  insert into public.environments (name, is_personal, created_by, created_at)
  values (v_name_clean, false, v_user_id, now())
  returning * into v_new_env;

  insert into public.environment_members (environment_id, user_id, role, joined_at)
  values (v_new_env.id, v_user_id, 'owner', now());

  return jsonb_build_object(
    'id', v_new_env.id,
    'name', v_new_env.name,
    'is_personal', v_new_env.is_personal,
    'created_by', v_new_env.created_by,
    'created_at', v_new_env.created_at,
    'role', 'owner'
  );
end;
$$ language plpgsql security definer;

-- RPC 2: delete_environment
create or replace function public.delete_environment(p_environment_id uuid)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_owner_id uuid;
  v_member_count int;
  v_is_personal boolean;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select created_by, is_personal into v_owner_id, v_is_personal
  from public.environments
  where id = p_environment_id;

  if v_owner_id is null then
    raise exception 'Entorno no encontrado';
  end if;

  if v_owner_id != v_user_id then
    raise exception 'Solo el propietario puede eliminar el entorno';
  end if;

  if v_is_personal then
    raise exception 'No se puede eliminar el entorno personal principal';
  end if;

  select count(*) into v_member_count
  from public.environment_members
  where environment_id = p_environment_id;

  if v_member_count > 1 then
    raise exception 'No se puede eliminar el entorno porque aún tiene miembros asociados. Debes expulsar a todos los miembros primero.';
  end if;

  delete from public.environments where id = p_environment_id;

  return jsonb_build_object('success', true, 'message', 'Entorno eliminado exitosamente');
end;
$$ language plpgsql security definer;

-- RPC 3: accept_environment_invitation
create or replace function public.accept_environment_invitation(p_invitation_id uuid)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_inv record;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select * into v_inv
  from public.environment_invitations
  where id = p_invitation_id;

  if v_inv is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_inv.receiver_id != v_user_id then
    raise exception 'No tienes permiso para aceptar esta invitación';
  end if;

  if v_inv.status != 'pending' then
    raise exception 'Esta invitación ya fue procesada';
  end if;

  update public.environment_invitations
  set status = 'accepted'
  where id = p_invitation_id;

  insert into public.environment_members (environment_id, user_id, role, joined_at)
  values (v_inv.environment_id, v_user_id, 'member', now())
  on conflict (environment_id, user_id) do update set role = 'member';

  return jsonb_build_object('success', true, 'environment_id', v_inv.environment_id);
end;
$$ language plpgsql security definer;

-- RPC 4: get_environment_members
create or replace function public.get_environment_members(p_environment_id uuid)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_is_member boolean;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select exists (
    select 1 from public.environment_members
    where environment_id = p_environment_id and user_id = v_user_id
  ) into v_is_member;

  if not v_is_member then
    raise exception 'No tienes acceso a los miembros de este entorno';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'environment_id', em.environment_id,
        'user_id', em.user_id,
        'role', em.role,
        'joined_at', em.joined_at,
        'username', coalesce(p.username, 'Usuario'),
        'avatar_type', coalesce(p.avatar_type, 'initials'),
        'avatar_url', p.avatar_url,
        'avatar_icon', p.avatar_icon,
        'avatar_bg_color', p.avatar_bg_color
      ) order by (em.role = 'owner') desc, em.joined_at asc
    ),
    '[]'::jsonb
  ) into v_result
  from public.environment_members em
  left join public.profiles p on p.id = em.user_id
  where em.environment_id = p_environment_id;

  return v_result;
end;
$$ language plpgsql security definer;

-- RPC 5: migrate_environment_content
create or replace function public.migrate_environment_content(
  source_environment_id uuid,
  target_environment_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_is_source_member boolean;
  v_is_target_member boolean;
  v_tables text[] := array['lists', 'items', 'recipes', 'notes'];
  t text;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select exists (
    select 1 from public.environment_members 
    where environment_id = source_environment_id and user_id = v_user_id
  ) into v_is_source_member;

  select exists (
    select 1 from public.environment_members 
    where environment_id = target_environment_id and user_id = v_user_id
  ) into v_is_target_member;

  if not v_is_source_member then
    raise exception 'No perteneces al entorno de origen';
  end if;
  if not v_is_target_member then
    raise exception 'No perteneces al entorno de destino';
  end if;

  foreach t in array v_tables loop
    if exists (
      select 1 from information_schema.columns 
      where table_schema = 'public' and table_name = t and column_name = 'environment_id'
    ) then
      if exists (
        select 1 from information_schema.columns 
        where table_schema = 'public' and table_name = t and column_name = 'created_by'
      ) then
        execute format(
          'update public.%I set environment_id = $1 where environment_id = $2 and created_by = $3',
          t
        ) using target_environment_id, source_environment_id, v_user_id;
      elsif exists (
        select 1 from information_schema.columns 
        where table_schema = 'public' and table_name = t and column_name = 'user_id'
      ) then
        execute format(
          'update public.%I set environment_id = $1 where environment_id = $2 and user_id = $3',
          t
        ) using target_environment_id, source_environment_id, v_user_id;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true, 
    'message', 'Contenido propio migrado exitosamente hacia el entorno destino'
  );
end;
$$ language plpgsql security definer;

-- RPC 6: Auto-Healing Atómico e Idempotente de Entorno Personal "Mi Espacio"
create or replace function public.ensure_personal_environment()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_env public.environments%rowtype;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  -- 1. Buscar si ya existe
  select * into v_env
  from public.environments
  where created_by = v_user_id and is_personal = true
  limit 1;

  -- 2. Si no existe, insertar de forma atómica con ON CONFLICT DO NOTHING
  if v_env.id is null then
    insert into public.environments (name, is_personal, created_by, created_at)
    values ('Mi Espacio', true, v_user_id, now())
    on conflict do nothing
    returning * into v_env;

    -- Si hubo conflicto concurrente, recuperar el registro existente
    if v_env.id is null then
      select * into v_env
      from public.environments
      where created_by = v_user_id and is_personal = true
      limit 1;
    end if;
  end if;

  -- 3. Garantizar membresía owner de forma idempotente
  insert into public.environment_members (environment_id, user_id, role, joined_at)
  values (v_env.id, v_user_id, 'owner', now())
  on conflict (environment_id, user_id) do nothing;

  return jsonb_build_object(
    'id', v_env.id,
    'name', v_env.name,
    'is_personal', v_env.is_personal,
    'created_by', v_env.created_by,
    'created_at', v_env.created_at,
    'role', 'owner'
  );
end;
$$ language plpgsql security definer;

-- Realtime: Exclusivamente para environment_invitations
alter table public.environment_invitations replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.environment_invitations;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;


