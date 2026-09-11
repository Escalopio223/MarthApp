-- ==============================================================================
-- MIGRACIÓN: 20260912_environments_and_members.sql
-- Módulo de Gestión de Entornos (Workspaces/Environments) para MarthApp
-- ==============================================================================

-- 1. Tabla de Entornos de Trabajo (Workspaces)
create table if not exists public.environments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_personal boolean not null default false,
  created_by uuid references auth.users(id) on delete cascade not null,
  created_at timestamp with time zone default now() not null
);

comment on table public.environments is 'Entornos de trabajo personales o colaborativos para usuarios';

-- 2. Tabla de Miembros del Entorno
create table if not exists public.environment_members (
  environment_id uuid references public.environments(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text not null check (role in ('owner', 'member')),
  joined_at timestamp with time zone default now() not null,
  primary key (environment_id, user_id)
);

comment on table public.environment_members is 'Membresías de usuarios en entornos de trabajo con rol asignado';

-- 3. Tabla de Invitaciones a Entornos
create table if not exists public.environment_invitations (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid references public.environments(id) on delete cascade not null,
  sender_id uuid references auth.users(id) on delete cascade not null,
  receiver_id uuid references auth.users(id) on delete cascade not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamp with time zone default now() not null
);

comment on table public.environment_invitations is 'Invitaciones enviadas para colaborar en un entorno de trabajo';

-- Índice único condicional: solo 1 invitación pendiente simultánea por entorno y receptor
create unique index if not exists idx_unique_pending_invitation 
  on public.environment_invitations (environment_id, receiver_id) 
  where status = 'pending';

-- Índice único condicional: garantiza como máximo 1 entorno personal por usuario (anti-race condition)
create unique index if not exists idx_unique_personal_environment
  on public.environments (created_by)
  where is_personal = true;

-- Índices de consulta rápida
create index if not exists idx_environments_created_by on public.environments (created_by);
create index if not exists idx_environments_is_personal on public.environments (is_personal);
create index if not exists idx_env_members_user on public.environment_members (user_id);
create index if not exists idx_env_invitations_receiver on public.environment_invitations (receiver_id);
create index if not exists idx_env_invitations_status on public.environment_invitations (status);

-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS DE SEGURIDAD ROW LEVEL SECURITY (RLS) NO RECURSIVAS
-- ------------------------------------------------------------------------------
alter table public.environments enable row level security;
alter table public.environment_members enable row level security;
alter table public.environment_invitations enable row level security;

-- RLS: environment_members
-- Lectura DIRECTA y O(1) sin subconsultas para romper bucles de recursión infinita
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

-- RLS: environments
-- Valida pertenencia consultando environment_members con evaluación directa
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

-- RLS: environment_invitations
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

-- ------------------------------------------------------------------------------
-- 5. FUNCIONES RPC TRANSACCIONALES
-- ------------------------------------------------------------------------------

-- RPC 1: Creación Atómica de Entorno (evita entornos huérfanos por cortes de red)
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

  -- 1. Inserción atómica del entorno
  insert into public.environments (name, is_personal, created_by, created_at)
  values (v_name_clean, false, v_user_id, now())
  returning * into v_new_env;

  -- 2. Inserción inmediata del creador como owner en la misma transacción
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

-- RPC 2: Eliminación Segura de Entorno con Regla Estricta de Miembros
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

  -- Validar restricción estricta: debe ser exactamente 1 (el owner)
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

-- RPC 3: Aceptación Atómica de Invitación a Entorno
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

  -- 1. Marcar como aceptada
  update public.environment_invitations
  set status = 'accepted'
  where id = p_invitation_id;

  -- 2. Insertar como miembro
  insert into public.environment_members (environment_id, user_id, role, joined_at)
  values (v_inv.environment_id, v_user_id, 'member', now())
  on conflict (environment_id, user_id) do update set role = 'member';

  return jsonb_build_object(
    'success', true,
    'environment_id', v_inv.environment_id
  );
end;
$$ language plpgsql security definer;

-- RPC 4: Consulta Segura de Miembros de un Entorno (sin riesgo de recursión en RLS)
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

  -- Validar que el invocador pertenezca al entorno
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

-- RPC 5: Migración Atómica de Contenido con Acotación Estricta de Autoría
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

  -- Validar membresía en ambos entornos
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

  -- Reasignación atómica con salvaguarda estricta de autoría (solo contenido propio)
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

-- ------------------------------------------------------------------------------
-- 6. TRIGGER AUTOMÁTICO DE NUEVO USUARIO (Crea "Mi Espacio" personal)
-- ------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------
-- 7. SCRIPT DE BACKFILL (Garantiza "Mi Espacio" a usuarios existentes)
-- ------------------------------------------------------------------------------
do $$
declare
  r record;
  v_new_env_id uuid;
begin
  for r in select id from public.profiles loop
    if not exists (
      select 1 from public.environments 
      where created_by = r.id and is_personal = true
    ) then
      insert into public.environments (name, is_personal, created_by, created_at)
      values ('Mi Espacio', true, r.id, now())
      returning id into v_new_env_id;

      insert into public.environment_members (environment_id, user_id, role, joined_at)
      values (v_new_env_id, r.id, 'owner', now())
      on conflict (environment_id, user_id) do nothing;
    end if;
  end loop;
end;
$$;

-- ------------------------------------------------------------------------------
-- 8. CONFIGURACIÓN SUPABASE REALTIME EXCLUSIVA PARA INVITACIONES
-- ------------------------------------------------------------------------------
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
