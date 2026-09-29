-- ==============================================================================
-- MarthApp: Script de Migración y Saneamiento de Cumpleaños
-- Rama: refactor/profile-birthday-dynamic-notifications
-- Ejecutar en el SQL Editor de tu Dashboard de Supabase
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ASEGURAR COLUMNA CANÓNICA EN public.profiles (Single Source of Truth)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS birth_date DATE;

-- ------------------------------------------------------------------------------
-- 2. MIGRACIÓN NO DESTRUCTIVA Y ELIMINACIÓN DE CAMPOS REDUNDANTES
-- Consolida cualquier valor previo de 'birthday', 'cumpleanos' o 'fecha_nacimiento'
-- hacia 'birth_date' antes de eliminar las columnas obsoletas.
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- 2.1. Migrar y podar 'birthday' si existe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'birthday'
  ) THEN
    EXECUTE 'UPDATE public.profiles SET birth_date = birthday::DATE WHERE birth_date IS NULL AND birthday IS NOT NULL';
    EXECUTE 'ALTER TABLE public.profiles DROP COLUMN birthday';
    RAISE NOTICE 'Columna redundante "birthday" migrada y eliminada con éxito.';
  END IF;

  -- 2.2. Migrar y podar 'cumpleanos' si existe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'cumpleanos'
  ) THEN
    EXECUTE 'UPDATE public.profiles SET birth_date = cumpleanos::DATE WHERE birth_date IS NULL AND cumpleanos IS NOT NULL';
    EXECUTE 'ALTER TABLE public.profiles DROP COLUMN cumpleanos';
    RAISE NOTICE 'Columna redundante "cumpleanos" migrada y eliminada con éxito.';
  END IF;

  -- 2.3. Migrar y podar 'fecha_nacimiento' si existe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'fecha_nacimiento'
  ) THEN
    EXECUTE 'UPDATE public.profiles SET birth_date = fecha_nacimiento::DATE WHERE birth_date IS NULL AND fecha_nacimiento IS NOT NULL';
    EXECUTE 'ALTER TABLE public.profiles DROP COLUMN fecha_nacimiento';
    RAISE NOTICE 'Columna redundante "fecha_nacimiento" migrada y eliminada con éxito.';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. ÍNDICES Y DOCUMENTACIÓN DE INTEGRIDAD
-- ------------------------------------------------------------------------------
COMMENT ON COLUMN public.profiles.birth_date IS 
  'Fecha canónica de nacimiento/cumpleaños del perfil (Single Source of Truth, formato YYYY-MM-DD).';

CREATE INDEX IF NOT EXISTS idx_profiles_birth_date 
  ON public.profiles (birth_date);

CREATE INDEX IF NOT EXISTS idx_profiles_birth_month_day 
  ON public.profiles (EXTRACT(MONTH FROM birth_date), EXTRACT(DAY FROM birth_date))
  WHERE birth_date IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 4. RPC AGRUPADA: CUMPLEAÑOS DINÁMICOS POR ENTORNO (Para la Edge Function)
-- Agrupa todos los cumpleañeros de un entorno (tanto perfiles de miembros con birth_date
-- como eventos manuales del Planificador de tipo 'cumpleanos') que coincidan en día y mes
-- con la fecha evaluada (recurrencia anual garantizada).
-- Intervalos evaluados: Hoy (0 días), 3 días, 7 días y 14 días.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.obtener_cumpleanos_entornos_recordatorios()
RETURNS TABLE (
  entorno_id UUID,
  dias_restantes INT,
  nombres_cumpleaneros TEXT[],
  usuario_ids UUID[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH todos_los_cumples AS (
    -- 4.1. Cumpleaños de perfiles de miembros del entorno (profiles.birth_date)
    SELECT 
      em.environment_id AS entorno_id,
      v.dias AS dias_restantes,
      COALESCE(NULLIF(TRIM(p.nombre_completo), ''), NULLIF(TRIM(p.username), ''), 'Miembro') AS nombre,
      em.user_id AS usuario_id
    FROM public.environment_members em
    JOIN public.profiles p ON p.id = em.user_id
    CROSS JOIN (VALUES (0), (3), (7), (14)) AS v(dias)
    WHERE p.birth_date IS NOT NULL
      AND EXTRACT(MONTH FROM p.birth_date) = EXTRACT(MONTH FROM (CURRENT_DATE + (v.dias || ' days')::interval))
      AND EXTRACT(DAY FROM p.birth_date) = EXTRACT(DAY FROM (CURRENT_DATE + (v.dias || ' days')::interval))

    UNION ALL

    -- 4.2. Eventos de tipo cumpleaños guardados en el Planificador (recurrentes anualmente)
    SELECT 
      e.entorno_id,
      v.dias AS dias_restantes,
      COALESCE(
        NULLIF(TRIM(e.persona_cumpleanos), ''), 
        NULLIF(TRIM(REGEXP_REPLACE(TRIM(e.titulo), '^cumpleaños\s+(de\s+)?', '', 'i')), ''),
        NULLIF(TRIM(e.titulo), ''), 
        'Cumpleaños'
      ) AS nombre,
      NULL::UUID AS usuario_id
    FROM public.planificador_eventos e
    CROSS JOIN (VALUES (0), (3), (7), (14)) AS v(dias)
    WHERE e.tipo = 'cumpleanos'
      AND EXTRACT(MONTH FROM e.fecha_inicio) = EXTRACT(MONTH FROM (CURRENT_DATE + (v.dias || ' days')::interval))
      AND EXTRACT(DAY FROM e.fecha_inicio) = EXTRACT(DAY FROM (CURRENT_DATE + (v.dias || ' days')::interval))
  )
  SELECT 
    t.entorno_id,
    t.dias_restantes,
    array_agg(t.nombre ORDER BY t.nombre) AS nombres_cumpleaneros,
    array_agg(t.usuario_id ORDER BY t.nombre) AS usuario_ids
  FROM todos_los_cumples t
  GROUP BY t.entorno_id, t.dias_restantes;
$$;

COMMENT ON FUNCTION public.obtener_cumpleanos_entornos_recordatorios() IS 
  'Retorna cumpleañeros agrupados por entorno (perfiles y eventos del planificador) cuyos aniversarios coinciden hoy o en 3, 7, 14 días.';

GRANT EXECUTE ON FUNCTION public.obtener_cumpleanos_entornos_recordatorios() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. RPC INDIVIDUAL (Retrocompatibilidad con eventos del Planificador)
-- Incluye automáticamente los perfiles canónicos (profiles.birth_date) + eventos manuales.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.planificador_obtener_cumpleanos_recordatorios()
RETURNS TABLE (
  entorno_id UUID,
  evento_id UUID,
  persona_cumpleanos TEXT,
  ideas_regalo TEXT,
  dias_restantes INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- 5.1. Cumpleaños canónicos desde profiles asociados a miembros del entorno
  SELECT 
    em.environment_id AS entorno_id,
    NULL::UUID AS evento_id,
    COALESCE(NULLIF(TRIM(p.nombre_completo), ''), NULLIF(TRIM(p.username), ''), 'Miembro') AS persona_cumpleanos,
    NULL::TEXT AS ideas_regalo,
    v.dias AS dias_restantes
  FROM public.environment_members em
  JOIN public.profiles p ON p.id = em.user_id
  CROSS JOIN (VALUES (0), (3), (7), (14)) AS v(dias)
  WHERE p.birth_date IS NOT NULL
    AND EXTRACT(MONTH FROM p.birth_date) = EXTRACT(MONTH FROM (CURRENT_DATE + (v.dias || ' days')::interval))
    AND EXTRACT(DAY FROM p.birth_date) = EXTRACT(DAY FROM (CURRENT_DATE + (v.dias || ' days')::interval))

  UNION ALL

  -- 5.2. Eventos explícitos de tipo cumpleaños en planificador_eventos (retrocompatibilidad)
  SELECT 
    e.entorno_id,
    e.id AS evento_id,
    COALESCE(
      NULLIF(TRIM(e.persona_cumpleanos), ''), 
      NULLIF(TRIM(REGEXP_REPLACE(TRIM(e.titulo), '^cumpleaños\s+(de\s+)?', '', 'i')), ''),
      'Cumpleaños'
    ) AS persona_cumpleanos,
    e.ideas_regalo,
    v.dias AS dias_restantes
  FROM public.planificador_eventos e
  CROSS JOIN (VALUES (0), (3), (7), (14)) AS v(dias)
  WHERE e.tipo = 'cumpleanos'
    AND EXTRACT(MONTH FROM e.fecha_inicio) = EXTRACT(MONTH FROM (CURRENT_DATE + (v.dias || ' days')::interval))
    AND EXTRACT(DAY FROM e.fecha_inicio) = EXTRACT(DAY FROM (CURRENT_DATE + (v.dias || ' days')::interval));
$$;

GRANT EXECUTE ON FUNCTION public.planificador_obtener_cumpleanos_recordatorios() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 6. ELIMINAR EL CAMPO TÍTULO EN CUMPLEAÑOS Y DEJAR SOLO EL NOMBRE
-- ------------------------------------------------------------------------------
ALTER TABLE public.planificador_eventos 
  ALTER COLUMN titulo DROP NOT NULL;

-- 6.1. Rescatar el nombre si persona_cumpleanos estaba vacío
UPDATE public.planificador_eventos
SET persona_cumpleanos = TRIM(REGEXP_REPLACE(TRIM(titulo), '^cumpleaños\s+(de\s+)?', '', 'i'))
WHERE tipo = 'cumpleanos'
  AND (persona_cumpleanos IS NULL OR TRIM(persona_cumpleanos) = '')
  AND titulo IS NOT NULL
  AND titulo ~* '^cumpleaños';

-- 6.2. Eliminar completamente el título de todos los cumpleaños
UPDATE public.planificador_eventos
SET titulo = NULL
WHERE tipo = 'cumpleanos';

-- ------------------------------------------------------------------------------
-- 7. CONSULTAS DE COMPROBACIÓN INMEDIATA (Opcionales para ejecutar tras el script)
-- ------------------------------------------------------------------------------
-- A. Comprobar que en 'profiles' solo existe 'birth_date':
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'profiles' AND column_name IN ('birth_date', 'birthday', 'cumpleanos', 'fecha_nacimiento');

-- B. Ver cumpleaños saneados (solo nombre, ideas_regalo y fecha):
-- SELECT id, persona_cumpleanos AS nombre, ideas_regalo, fecha_inicio FROM public.planificador_eventos WHERE tipo = 'cumpleanos';
