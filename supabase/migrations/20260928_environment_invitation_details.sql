-- ==============================================================================
-- MIGRACIÓN: 20260928_environment_invitation_details.sql
-- Ampliación de detalles para invitaciones a entornos:
-- Permite visualizar nombre, foto del anfitrión, entorno y todos los integrantes
-- ==============================================================================

-- 1. Actualización de permisos en get_environment_members para permitir lectura a invitados pendientes
create or replace function public.get_environment_members(p_environment_id uuid)
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_has_access boolean;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  -- El usuario tiene acceso si ya es miembro del entorno O si tiene una invitación pendiente
  select exists (
    select 1 from public.environment_members
    where environment_id = p_environment_id and user_id = v_user_id
  ) or exists (
    select 1 from public.environment_invitations
    where environment_id = p_environment_id and receiver_id = v_user_id and status = 'pending'
  ) into v_has_access;

  if not v_has_access then
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

-- 2. RPC atómico para obtener todas las invitaciones pendientes con datos completos de remitente e integrantes
create or replace function public.get_pending_environment_invitations()
returns jsonb as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ei.id,
        'environment_id', ei.environment_id,
        'environment_name', coalesce(e.name, 'Entorno'),
        'sender_id', ei.sender_id,
        'sender_username', coalesce(sp.username, 'Amigo'),
        'sender_avatar_type', sp.avatar_type,
        'sender_avatar_url', sp.avatar_url,
        'sender_avatar_icon', sp.avatar_icon,
        'sender_avatar_bg_color', sp.avatar_bg_color,
        'receiver_id', ei.receiver_id,
        'status', ei.status,
        'created_at', ei.created_at,
        'members', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'environment_id', em.environment_id,
              'user_id', em.user_id,
              'role', em.role,
              'joined_at', em.joined_at,
              'username', coalesce(mp.username, 'Usuario'),
              'avatar_type', coalesce(mp.avatar_type, 'initials'),
              'avatar_url', mp.avatar_url,
              'avatar_icon', mp.avatar_icon,
              'avatar_bg_color', mp.avatar_bg_color
            ) order by (em.role = 'owner') desc, em.joined_at asc
          )
          from public.environment_members em
          left join public.profiles mp on mp.id = em.user_id
          where em.environment_id = ei.environment_id
        ), '[]'::jsonb)
      ) order by ei.created_at desc
    ),
    '[]'::jsonb
  ) into v_result
  from public.environment_invitations ei
  left join public.environments e on e.id = ei.environment_id
  left join public.profiles sp on sp.id = ei.sender_id
  where ei.receiver_id = v_user_id and ei.status = 'pending';

  return v_result;
end;
$$ language plpgsql security definer;
