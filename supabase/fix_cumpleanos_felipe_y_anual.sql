-- ==============================================================================
-- FIX DEFINITIVO: ELIMINAR CAMPO TÍTULO EN CUMPLEAÑOS Y ACTIVAR RECURRENCIA ANUAL
-- ==============================================================================
-- 1. Elimina la restricción NOT NULL de la columna 'titulo' en planificador_eventos.
-- 2. Asegura que 'persona_cumpleanos' contenga el nombre limpio (ej. "Felipe", "Tata").
-- 3. ELIMINA/VACÍA el campo 'titulo' (SET titulo = NULL) para todos los cumpleaños.
-- 4. Actualiza las funciones RPC para usar directamente el nombre sin depender de 'titulo'.
-- 5. Garantiza recurrencia anual (coincidencia de día y mes sin importar el año).
-- ==============================================================================

-- PASO 1: Permitir que 'titulo' sea opcional (NULL) en planificador_eventos
ALTER TABLE public.planificador_eventos 
  ALTER COLUMN titulo DROP NOT NULL;

-- PASO 2: Rescatar el nombre si 'persona_cumpleanos' estaba vacío
UPDATE public.planificador_eventos
SET persona_cumpleanos = TRIM(REGEXP_REPLACE(TRIM(titulo), '^cumpleaños\s+(de\s+)?', '', 'i'))
WHERE tipo = 'cumpleanos'
  AND (persona_cumpleanos IS NULL OR TRIM(persona_cumpleanos) = '')
  AND titulo IS NOT NULL
  AND titulo ~* '^cumpleaños';

-- PASO 3: ELIMINAR EL CAMPO TÍTULO de todos los cumpleaños (dejarlo en NULL)
UPDATE public.planificador_eventos
SET titulo = NULL
WHERE tipo = 'cumpleanos';

-- PASO 4: RPC agrupada para la Edge Function (incluye profiles + planificador_eventos)
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
    -- Cumpleaños de perfiles de miembros del entorno (profiles.birth_date)
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

    -- Eventos de tipo cumpleaños guardados en el Planificador (recurrentes anualmente)
    SELECT 
      e.entorno_id,
      v.dias AS dias_restantes,
      COALESCE(
        NULLIF(TRIM(e.persona_cumpleanos), ''), 
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

-- PASO 5: RPC individual para retrocompatibilidad
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
  -- Cumpleaños canónicos desde profiles asociados a miembros del entorno
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

  -- Eventos explícitos de tipo cumpleaños en planificador_eventos (sin campo titulo)
  SELECT 
    e.entorno_id,
    e.id AS evento_id,
    COALESCE(
      NULLIF(TRIM(e.persona_cumpleanos), ''), 
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

-- PASO 6: Verificación (Solo el nombre de la persona, ideas de regalo y fecha. SIN campo título)
SELECT id, persona_cumpleanos AS nombre, ideas_regalo, fecha_inicio 
FROM public.planificador_eventos 
WHERE tipo = 'cumpleanos';
