-- ==============================================================================
-- Migración: Corrección de Expulsión/Salida de Miembros y Eliminación de Entornos
-- Fecha: 2026-09-19
-- ==============================================================================
-- 1. Crea la RPC segura `remove_environment_member` (SECURITY DEFINER) para
--    permitir al propietario expulsar miembros (o a un miembro salir) sin ser
--    bloqueado por las restricciones de visibilidad RLS de SELECT en environment_members.
-- 2. Sincroniza el borrado con `entorno_usuarios` (Planificador) y cancela invitaciones pendientes.
-- 3. Actualiza `delete_environment` para limpiar también la tabla `entornos` si existe.
-- 4. Actualiza `migrate_environment_content` para incluir listas de ocio (leisure_shared_lists).
-- ==============================================================================

-- 1. RPC: Expulsar o abandonar miembro de un entorno de forma atómica y segura
create or replace function public.remove_environment_member(
  p_environment_id uuid,
  p_user_id uuid
)
returns jsonb as $$
declare
  v_caller_id uuid := auth.uid();
  v_owner_id uuid;
  v_is_personal boolean;
begin
  -- 1. Validar autenticación
  if v_caller_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  -- 2. Validar que el entorno exista y obtener propietario
  select created_by, is_personal into v_owner_id, v_is_personal
  from public.environments
  where id = p_environment_id;

  if v_owner_id is null then
    raise exception 'El entorno especificado no existe';
  end if;

  if v_is_personal then
    raise exception 'No se pueden expulsar miembros del entorno personal';
  end if;

  -- 3. Validar permisos: solo el propietario puede expulsar a otros miembros,
  --    o el propio miembro puede abandonar voluntariamente
  if v_caller_id != v_owner_id and v_caller_id != p_user_id then
    raise exception 'No tienes permisos para expulsar a este usuario del entorno';
  end if;

  -- 4. Impedir expulsar al propio propietario (el propietario debe transferir o eliminar el entorno)
  if p_user_id = v_owner_id then
    raise exception 'No se puede expulsar al propietario del entorno. Para cerrarlo debes eliminar el entorno.';
  end if;

  -- 5. Eliminar la membresía de environment_members
  delete from public.environment_members
  where environment_id = p_environment_id and user_id = p_user_id;

  -- 6. Eliminar de entorno_usuarios si la tabla existe (compatibilidad con módulo Planificador)
  if exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'entorno_usuarios') then
    delete from public.entorno_usuarios
    where entorno_id = p_environment_id and user_id = p_user_id;
  end if;

  -- 7. Limpiar invitaciones pendientes hacia o desde este usuario para este entorno
  delete from public.environment_invitations
  where environment_id = p_environment_id and (receiver_id = p_user_id or sender_id = p_user_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Miembro eliminado exitosamente del entorno'
  );
end;
$$ language plpgsql security definer;

-- Otorgar permisos de ejecución a usuarios autenticados
grant execute on function public.remove_environment_member(uuid, uuid) to authenticated;

-- 2. Actualizar RPC: delete_environment para garantizar limpieza atómica completa
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

  -- Eliminar de la tabla pública environments (las tablas con FK on delete cascade se limpiarán automáticamente)
  delete from public.environments where id = p_environment_id;

  -- Si existe la tabla entornos (del planificador), limpiarla para evitar registros huérfanos
  if exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'entornos') then
    delete from public.entornos where id = p_environment_id;
  end if;

  return jsonb_build_object('success', true, 'message', 'Entorno eliminado exitosamente');
end;
$$ language plpgsql security definer;

grant execute on function public.delete_environment(uuid) to authenticated;

-- 3. Actualizar RPC: migrate_environment_content para contemplar también leisure_shared_lists
create or replace function public.migrate_environment_content(
  source_environment_id uuid,
  target_environment_id uuid
)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_is_source_member boolean;
  v_is_target_member boolean;
  v_tables text[] := array['lists', 'items', 'recipes', 'notes', 'leisure_shared_lists'];
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

grant execute on function public.migrate_environment_content(uuid, uuid) to authenticated;
