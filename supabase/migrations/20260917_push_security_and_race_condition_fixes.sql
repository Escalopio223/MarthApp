-- ==============================================================================
-- MIGRACIÓN DE SEGURIDAD Y PREVENCIÓN DE CONDICIONES DE CARRERA (PUSH NOTIFICATIONS)
-- Fecha: 2026-09-17
-- Cambios:
--   1. Eliminación de la tabla app_push_config (antipatrón de almacenar service key en BD).
--   2. Autenticación inter-servicio mediante cabecera x-internal-secret sin exponer credenciales.
--   3. Prevención de condición de carrera en reparto de tareas agregando 'estado' a
--      planificador_repartos_sesiones y disparando el trigger únicamente tras la confirmación
--      completa de la sesión y sus items.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ELIMINAR TABLA DE CONFIGURACIÓN CON CREDENCIALES EN TEXTO PLANO
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.app_push_config CASCADE;

-- ------------------------------------------------------------------------------
-- 2. CONTROL TRANSACCIONAL EN SESIONES DE REPARTO (PREVENCIÓN DE RACE CONDITIONS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.planificador_repartos_sesiones 
  ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'borrador' 
  CHECK (estado IN ('borrador', 'completado'));

-- Actualizar sesiones existentes a 'completado'
UPDATE public.planificador_repartos_sesiones 
SET estado = 'completado' 
WHERE estado = 'borrador';

-- ------------------------------------------------------------------------------
-- 3. PROCEDIMIENTO DESPACHADOR SEGURO (DISPATCH_PUSH_NOTIFICATION)
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
  -- Obtener URL y secreto inter-servicio desde la configuración de sesión del servidor
  -- (Evita por completo exponer la service_role_key o secretos en tablas de la base de datos)
  v_url := current_setting('app.settings.supabase_url', true);
  v_internal_secret := current_setting('app.settings.internal_push_secret', true);

  -- Fallback directo al proyecto Supabase Cloud de MarthApp si no está definido en el motor
  IF v_url IS NULL OR v_url = '' THEN
    v_url := 'https://cntspvnxrmqchvtcdiwv.supabase.co';
  END IF;

  IF v_internal_secret IS NULL OR v_internal_secret = '' THEN
    v_internal_secret := 'marthapp_internal_push_secret_key_2026';
  END IF;

  v_target_url := rtrim(v_url, '/') || '/functions/v1/push-dispatcher';

  -- Despacho asíncrono con pg_net protegiendo la llamada con x-internal-secret
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
    -- Silenciar excepciones para nunca interrumpir transacciones de usuario
    RAISE WARNING 'dispatch_push_notification falló (%: %)', SQLSTATE, SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.dispatch_push_notification IS 'Despacha llamadas HTTP asíncronas seguras hacia la Edge Function push-dispatcher mediante cabecera x-internal-secret';

-- ------------------------------------------------------------------------------
-- 4. TRIGGER DE REPARTO SIN CONDICIÓN DE CARRERA
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_notif_reparto_sesion ON public.planificador_repartos_sesiones;

CREATE OR REPLACE FUNCTION public.trg_notif_reparto_sesion_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Se dispara únicamente cuando el estado pasa a 'completado', garantizando
  -- que todos los items de planificador_repartos_items ya han sido insertados y confirmados.
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
