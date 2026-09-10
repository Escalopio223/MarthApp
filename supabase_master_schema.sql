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
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
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

-- Trigger para crear automáticamente el perfil al registrarse en auth.users
create or replace function public.handle_new_user()
returns trigger as $$
declare
  raw_username text;
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
