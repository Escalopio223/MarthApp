-- ==============================================================================
-- Migración: Sistema de Amistades y Perfiles en Tiempo Real para MarthApp
-- Tablas: profiles, friend_requests
-- Políticas: Row Level Security (RLS)
-- Soporte: Supabase Realtime habilitado
-- ==============================================================================

-- 1. Crear tabla de perfiles de usuario
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS en profiles
alter table public.profiles enable row level security;

-- Políticas de seguridad para profiles
create policy "Los perfiles son visibles para todos los usuarios autenticados"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Los usuarios pueden insertar su propio perfil"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Los usuarios pueden actualizar exclusivamente su propio perfil"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 2. Crear tabla de solicitudes y relaciones de amistad
create table if not exists public.friend_requests (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  receiver_id uuid references public.profiles(id) on delete cascade not null,
  status text check (status in ('pending', 'accepted', 'rejected')) default 'pending' not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  -- Evitar solicitudes duplicadas entre la misma pareja de usuarios en la misma dirección
  constraint unique_friend_request unique (sender_id, receiver_id),
  -- No permitir que un usuario se envíe solicitud a sí mismo
  constraint cannot_friend_self check (sender_id <> receiver_id)
);

-- Habilitar RLS en friend_requests
alter table public.friend_requests enable row level security;

-- Políticas de seguridad para friend_requests
create policy "Los usuarios pueden ver solicitudes donde sean emisor o receptor"
  on public.friend_requests for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Los usuarios solo pueden enviar solicitudes como emisor"
  on public.friend_requests for insert
  to authenticated
  with check (
    auth.uid() = sender_id and
    sender_id <> receiver_id
  );

create policy "Emisor o receptor pueden actualizar el estado de una solicitud"
  on public.friend_requests for update
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id)
  with check (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Emisor o receptor pueden eliminar una solicitud o amistad"
  on public.friend_requests for delete
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- 3. Índices para acelerar búsquedas y filtros en tiempo real
create index if not exists idx_profiles_username_lower on public.profiles (lower(username));
create index if not exists idx_friend_requests_sender on public.friend_requests (sender_id);
create index if not exists idx_friend_requests_receiver on public.friend_requests (receiver_id);
create index if not exists idx_friend_requests_status on public.friend_requests (status);

-- 4. Trigger para auto-crear el perfil tras el registro en auth.users
create or replace function public.handle_new_user()
returns trigger as $$
declare
  raw_username text;
begin
  -- Obtener username de los metadatos de usuario o del prefijo del correo
  raw_username := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1)
  );

  -- Si el username ya existe, añadir un sufijo aleatorio de 4 caracteres
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

-- Asignar trigger a auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5. Configurar réplica en tiempo real (Supabase Realtime)
-- REPLICA IDENTITY FULL asegura que los payloads de UPDATE/DELETE contengan datos anteriores y nuevos
alter table public.profiles replica identity full;
alter table public.friend_requests replica identity full;

-- Añadir tablas a la publicación de Realtime de Supabase
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.profiles, public.friend_requests;
  end if;
exception
  when duplicate_object then
    null;
end;
$$;
