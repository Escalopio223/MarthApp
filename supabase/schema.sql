-- ==============================================================================
-- MarthApp - Esquema de Base de Datos para Supabase
-- ==============================================================================
-- Este script configura la persistencia de usuarios, perfiles con soporte OAuth,
-- sistema de códigos de amigo temporales (1 minuto) y relaciones de amistad.
-- Ejecútalo en el SQL Editor de tu Dashboard de Supabase.
-- ==============================================================================

-- 1. Tabla de Perfiles Públicos (vinculada a auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Comentarios descriptivos
comment on table public.profiles is 'Perfiles públicos de usuario sincronizados desde Supabase Auth';

-- 2. Trigger automático para sincronizar auth.users -> public.profiles
-- Extrae automáticamente los metadatos generados por Google, GitHub, Discord y Twitter
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'user_name',
      split_part(new.email, '@', 1)
    ),
    coalesce(
      new.raw_user_meta_data->>'avatar_url',
      new.raw_user_meta_data->>'picture'
    )
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url),
    updated_at = timezone('utc'::text, now());

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. Tabla de Códigos de Amigo Temporales (1 minuto de validez)
create table if not exists public.friend_codes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  code text not null unique,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone default (timezone('utc'::text, now()) + interval '1 minute') not null
);

create index if not exists idx_friend_codes_code on public.friend_codes(code);
create index if not exists idx_friend_codes_expires_at on public.friend_codes(expires_at);

comment on table public.friend_codes is 'Códigos de amigo temporales válidos durante 1 minuto';

-- 4. Tabla de Amistades (Relaciones mutuas o directas)
create table if not exists public.friendships (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  friend_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint unique_friendship unique(user_id, friend_id),
  constraint no_self_friending check (user_id <> friend_id)
);

-- 5. Configuración de Políticas RLS (Row Level Security)
alter table public.profiles enable row level security;
alter table public.friend_codes enable row level security;
alter table public.friendships enable row level security;

-- Políticas para profiles:
-- Cualquiera autenticado puede leer perfiles públicos
create policy "Perfiles visibles para usuarios autenticados"
  on public.profiles for select
  to authenticated
  using (true);

-- Solo el propietario puede actualizar su perfil
create policy "Usuarios pueden actualizar su propio perfil"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Políticas para friend_codes:
-- Solo el creador puede insertar sus propios códigos
create policy "Usuarios pueden generar su propio código"
  on public.friend_codes for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Todos los autenticados pueden consultar códigos no expirados
create policy "Códigos activos visibles para autenticados"
  on public.friend_codes for select
  to authenticated
  using (expires_at > timezone('utc'::text, now()));

-- Políticas para friendships:
create policy "Usuarios pueden ver sus amistades"
  on public.friendships for select
  to authenticated
  using (auth.uid() = user_id or auth.uid() = friend_id);

-- 6. Función RPC atómica para canjear código de amigo de 1 minuto
create or replace function public.redeem_friend_code(p_code text)
returns json as $$
declare
  v_caller_id uuid := auth.uid();
  v_target_user_id uuid;
  v_friend_profile public.profiles%rowtype;
begin
  -- 1. Validar que el usuario esté autenticado
  if v_caller_id is null then
    return json_build_object('success', false, 'error', 'No autenticado');
  end if;

  -- 2. Buscar el código y verificar que siga vigente (1 minuto)
  select user_id into v_target_user_id
  from public.friend_codes
  where code = upper(trim(p_code))
    and expires_at > timezone('utc'::text, now());

  if v_target_user_id is null then
    return json_build_object('success', false, 'error', 'El código es inválido o ya ha expirado (más de 1 minuto)');
  end if;

  -- 3. Evitar agregarse a uno mismo
  if v_target_user_id = v_caller_id then
    return json_build_object('success', false, 'error', 'No puedes añadirte a ti mismo como amigo');
  end if;

  -- 4. Verificar si ya son amigos
  if exists (
    select 1 from public.friendships
    where user_id = v_caller_id and friend_id = v_target_user_id
  ) then
    return json_build_object('success', false, 'error', 'Ya eres amigo de este usuario');
  end if;

  -- 5. Crear la amistad en ambos sentidos (bidireccional)
  insert into public.friendships (user_id, friend_id)
  values (v_caller_id, v_target_user_id)
  on conflict do nothing;

  insert into public.friendships (user_id, friend_id)
  values (v_target_user_id, v_caller_id)
  on conflict do nothing;

  -- 6. Obtener datos del amigo añadido para devolver en la respuesta
  select * into v_friend_profile from public.profiles where id = v_target_user_id;

  return json_build_object(
    'success', true,
    'friend_id', v_target_user_id,
    'full_name', v_friend_profile.full_name,
    'email', v_friend_profile.email
  );
end;
$$ language plpgsql security definer;
