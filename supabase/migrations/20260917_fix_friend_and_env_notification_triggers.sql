-- ==============================================================================
-- CORRECCIÓN INMEDIATA: Triggers de Notificaciones de Amistad y Entornos
-- ==============================================================================
-- Corrige el error: column "nombre_completo" does not exist
-- En la tabla public.profiles el campo identificador es 'username'.
-- En la tabla public.environments el campo identificador es 'name'.
-- ==============================================================================

-- 1. Añadir columna opcional nombre_completo a profiles por compatibilidad futura
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nombre_completo TEXT;

-- 2. Corregir trigger de solicitudes de amistad
CREATE OR REPLACE FUNCTION public.trg_notif_friend_request_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(nombre_completo, username, 'Un usuario')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

    PERFORM public.dispatch_push_notification(
      'immediate',
      jsonb_build_object(
        'user_ids', jsonb_build_array(NEW.receiver_id),
        'title', 'Nueva solicitud de amistad',
        'body', COALESCE(v_sender_name, 'Un usuario') || ' te ha enviado una solicitud de amistad.',
        'data', jsonb_build_object(
          'type', 'friend_request',
          'request_id', NEW.id,
          'sender_id', NEW.sender_id
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_friend_request ON public.friend_requests;
CREATE TRIGGER trg_notif_friend_request
  AFTER INSERT ON public.friend_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notif_friend_request_func();

-- 3. Corregir trigger de invitaciones a entornos
CREATE OR REPLACE FUNCTION public.trg_notif_env_invitation_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_name TEXT;
  v_env_name TEXT;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(nombre_completo, username, 'Un miembro')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

    SELECT COALESCE(name, 'un entorno')
    INTO v_env_name
    FROM public.environments
    WHERE id = NEW.environment_id;

    PERFORM public.dispatch_push_notification(
      'immediate',
      jsonb_build_object(
        'user_ids', jsonb_build_array(NEW.receiver_id),
        'title', 'Invitación a colaborar',
        'body', COALESCE(v_sender_name, 'Un miembro') || ' te ha invitado a unirte a "' || COALESCE(v_env_name, 'un entorno') || '".',
        'data', jsonb_build_object(
          'type', 'environment_invitation',
          'invitation_id', NEW.id,
          'environment_id', NEW.environment_id
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_env_invitation ON public.environment_invitations;
CREATE TRIGGER trg_notif_env_invitation
  AFTER INSERT ON public.environment_invitations
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notif_env_invitation_func();
