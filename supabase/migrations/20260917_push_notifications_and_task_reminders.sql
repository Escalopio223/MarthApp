-- ==============================================================================
-- MIGRACIÓN: Sistema Global de Notificaciones Push y Recordatorios de Tareas
-- Fecha: 2026-09-17
-- Descripción:
--   1. Configuración y tabla dedicada 'planificador_tarea_recordatorios'.
--   2. Flexibilización de 'usuario_fcm_tokens' para asociar dispositivos directamente al usuario.
--   3. Función despachadora asíncrona 'dispatch_push_notification' vía pg_net.
--   4. Triggers automáticos e inmediatos para:
--      - Solicitudes de amistad (friend_requests)
--      - Invitaciones a entornos (environment_invitations)
--      - Repartos equitativos aplicados (planificador_repartos_sesiones)
--   5. Configuración y automatización para recordatorios programados (pg_cron).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Extensiones requeridas
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA pg_catalog;

-- ------------------------------------------------------------------------------
-- 2. Seguridad: Garantizar eliminación de cualquier tabla de credenciales
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.app_push_config CASCADE;

-- Control transaccional en sesiones de reparto (Prevención de condición de carrera)
ALTER TABLE public.planificador_repartos_sesiones 
  ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'borrador' 
  CHECK (estado IN ('borrador', 'completado'));

-- ------------------------------------------------------------------------------
-- 3. Tabla: planificador_tarea_recordatorios
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_tarea_recordatorios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tarea_id UUID NOT NULL REFERENCES public.planificador_tareas(id) ON DELETE CASCADE,
  fecha_notificacion DATE NOT NULL,
  hora_notificacion TIME NULL,
  enviado BOOLEAN NOT NULL DEFAULT false,
  ultimo_envio_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.planificador_tarea_recordatorios IS 'Recordatorios programables por tarea con fecha, hora opcional y ciclo de repetición cada 8h';

-- Índices de alto rendimiento
CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_tarea_id 
  ON public.planificador_tarea_recordatorios (tarea_id);

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_escaneo 
  ON public.planificador_tarea_recordatorios (fecha_notificacion, hora_notificacion, enviado);

-- RLS para planificador_tarea_recordatorios
ALTER TABLE public.planificador_tarea_recordatorios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recordatorios_select" ON public.planificador_tarea_recordatorios;
CREATE POLICY "recordatorios_select" ON public.planificador_tarea_recordatorios
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_tareas t
      WHERE t.id = planificador_tarea_recordatorios.tarea_id
        AND public.planificador_usuario_es_miembro_entorno(t.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "recordatorios_insert" ON public.planificador_tarea_recordatorios;
CREATE POLICY "recordatorios_insert" ON public.planificador_tarea_recordatorios
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_tareas t
      WHERE t.id = planificador_tarea_recordatorios.tarea_id
        AND public.planificador_usuario_es_miembro_entorno(t.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "recordatorios_update" ON public.planificador_tarea_recordatorios;
CREATE POLICY "recordatorios_update" ON public.planificador_tarea_recordatorios
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_tareas t
      WHERE t.id = planificador_tarea_recordatorios.tarea_id
        AND public.planificador_usuario_es_miembro_entorno(t.entorno_id, auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_tareas t
      WHERE t.id = planificador_tarea_recordatorios.tarea_id
        AND public.planificador_usuario_es_miembro_entorno(t.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "recordatorios_delete" ON public.planificador_tarea_recordatorios;
CREATE POLICY "recordatorios_delete" ON public.planificador_tarea_recordatorios
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_tareas t
      WHERE t.id = planificador_tarea_recordatorios.tarea_id
        AND public.planificador_usuario_es_miembro_entorno(t.entorno_id, auth.uid())
    )
  );

-- ------------------------------------------------------------------------------
-- 4. Ajustes en usuario_fcm_tokens (Vincular tokens al dispositivo del usuario)
-- ------------------------------------------------------------------------------
-- Permitir que un token pertenezca directamente al usuario sin exigir un entorno activo
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'usuario_fcm_tokens' 
      AND column_name = 'entorno_id' 
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.usuario_fcm_tokens ALTER COLUMN entorno_id DROP NOT NULL;
  END IF;
END $$;

-- Asegurar políticas RLS para usuario_fcm_tokens basadas en auth.uid() = user_id
DROP POLICY IF EXISTS "fcm_tokens_select" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_select" ON public.usuario_fcm_tokens
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "fcm_tokens_insert" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_insert" ON public.usuario_fcm_tokens
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "fcm_tokens_update" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_update" ON public.usuario_fcm_tokens
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "fcm_tokens_delete" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_delete" ON public.usuario_fcm_tokens
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 5. Función despachadora HTTP PostgreSQL vía pg_net (Segura y no bloqueante)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_push_notification(
  p_mode TEXT,
  p_payload JSONB
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_url TEXT;
  v_internal_secret TEXT;
  v_target_url TEXT;
BEGIN
  -- 1. Leer parámetros de sesión del motor (sin exponer claves en tablas públicas)
  v_url := current_setting('app.settings.supabase_url', true);
  v_internal_secret := current_setting('app.settings.internal_push_secret', true);

  IF (v_url IS NULL OR v_url = '') THEN
    v_url := 'https://cntspvnxrmqchvtcdiwv.supabase.co';
  END IF;

  IF (v_internal_secret IS NULL OR v_internal_secret = '') THEN
    v_internal_secret := 'marthapp_internal_push_secret_key_2026';
  END IF;

  v_target_url := rtrim(v_url, '/') || '/functions/v1/push-dispatcher';
  
  -- 2. Despacho asíncrono con x-internal-secret
  PERFORM net.http_post(
    url := v_target_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-internal-secret', v_internal_secret
    ),
    body := jsonb_build_object(
      'mode', p_mode,
      'payload', p_payload
    ),
    timeout_milliseconds := 15000
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'dispatch_push_notification: Error en despacho HTTP (%: %)', SQLSTATE, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.dispatch_push_notification IS 'Despacha un evento de notificación push hacia la Edge Function push-dispatcher usando pg_net';

-- ------------------------------------------------------------------------------
-- 6. TRIGGERS INMEDIATOS (EVENT-DRIVEN)
-- ------------------------------------------------------------------------------

-- 6.1. Notificación: Solicitud de amistad recibida
CREATE OR REPLACE FUNCTION public.trg_notif_friend_request_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  -- Solo actuar en solicitudes entrantes con estado 'pending'
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(username, 'Un usuario')
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

-- 6.2. Notificación: Invitación a un entorno/hogar recibida
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
    -- Obtener nombre del remitente
    SELECT COALESCE(username, 'Un miembro')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

    -- Obtener nombre del entorno
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

-- 6.3. Notificación: Reparto equitativo de tareas ejecutado / aplicado
DROP TRIGGER IF EXISTS trg_notif_reparto_sesion ON public.planificador_repartos_sesiones;

CREATE OR REPLACE FUNCTION public.trg_notif_reparto_sesion_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Solo despachar cuando el estado pasa a 'completado', garantizando que todos los items
  -- de planificador_repartos_items ya han sido insertados y confirmados.
  IF (TG_OP = 'UPDATE' AND OLD.estado IS DISTINCT FROM 'completado' AND NEW.estado = 'completado')
     OR (TG_OP = 'INSERT' AND NEW.estado = 'completado') THEN
    PERFORM public.dispatch_push_notification(
      'immediate',
      jsonb_build_object(
        'type', 'reparto_sesion',
        'sesion_id', NEW.id,
        'entorno_id', NEW.entorno_id,
        'usuarios_participantes', to_jsonb(NEW.usuarios_participantes),
        'minutos_totales', NEW.minutos_totales
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notif_reparto_sesion
  AFTER INSERT OR UPDATE OF estado ON public.planificador_repartos_sesiones
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notif_reparto_sesion_func();

-- ------------------------------------------------------------------------------
-- 7. Recordatorios Programados (pg_cron)
-- ------------------------------------------------------------------------------
-- Procedimiento invocado periódicamente por pg_cron
CREATE OR REPLACE FUNCTION public.cron_dispatch_scheduled_reminders()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.dispatch_push_notification(
    'scheduled',
    jsonb_build_object(
      'source', 'pg_cron',
      'timestamp', now()
    )
  );
END;
$$;

COMMENT ON FUNCTION public.cron_dispatch_scheduled_reminders IS 'Invoca la Edge Function push-dispatcher en modo programado para evaluar y enviar recordatorios de tareas';

-- Programación horaria en pg_cron (ejecuta cada hora al minuto 0)
-- NOTA: Si utilizas pg_cron en Supabase, ejecuta el siguiente bloque para habilitar el job:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'push-dispatcher-scheduled-hourly') THEN
    PERFORM cron.unschedule('push-dispatcher-scheduled-hourly');
  END IF;
  
  -- Programar cada 60 minutos
  PERFORM cron.schedule(
    'push-dispatcher-scheduled-hourly',
    '0 * * * *',
    'SELECT public.cron_dispatch_scheduled_reminders();'
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron no disponible o sin permisos suficientes: %', SQLERRM;
END $$;
