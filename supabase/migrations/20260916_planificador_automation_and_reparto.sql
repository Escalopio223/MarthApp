-- ==============================================================================
-- MÓDULO PLANIFICADOR: LÓGICA DE SERVIDOR, REPARTO EQUITATIVO Y AUTOMATIZACIÓN
-- ==============================================================================
-- 1. Función determinista de Reparto Equitativo (Greedy Partition Problem)
-- 2. Funciones RPC para la Edge Function de Recordatorios (Cumpleaños y Tareas)
-- 3. Programación cron (pg_cron + pg_net) para ejecución diaria a las 08:00 AM UTC
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ALGORITMO DETERMINISTA DE REPARTO EQUITATIVO (Greedy Partition Heuristic)
-- ------------------------------------------------------------------------------
-- Heurística LPT (Longest Processing Time First):
-- - Ordena tareas pendientes de mayor a menor tiempo_estimado_minutos.
-- - Desempate de tareas por UUID (id ASC) para garantizar determinismo estricto.
-- - Asigna cada tarea al usuario participante con menor tiempo acumulado en la sesión.
-- - Desempate de usuarios por orden posicional en p_usuarios_participantes.
-- - Inserta en planificador_repartos_sesiones y planificador_repartos_items.
-- - Actualiza la columna asignado_a en planificador_tareas.
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.planificador_ejecutar_reparto_equitativo(
  p_entorno_id UUID,
  p_usuarios_participantes UUID[],
  p_tarea_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_sesion_id UUID := gen_random_uuid();
  v_minutos_totales INT := 0;
  v_num_usuarios INT;
  v_tareas_count INT := 0;
  
  -- Estructura de cargas acumuladas por participante: { "<user_id>": minutos }
  v_user_loads JSONB := '{}'::jsonb;
  v_task RECORD;
  v_selected_user UUID;
  v_min_load INT;
  v_current_user UUID;
  v_current_load INT;
  v_initial_user UUID;
  
  v_items_inserted JSONB := '[]'::jsonb;
BEGIN
  -- 1. Validaciones previas
  IF p_entorno_id IS NULL THEN
    RAISE EXCEPTION 'El parámetro p_entorno_id es obligatorio';
  END IF;

  v_num_usuarios := array_length(p_usuarios_participantes, 1);
  IF v_num_usuarios IS NULL OR v_num_usuarios = 0 THEN
    RAISE EXCEPTION 'Debe especificarse al menos un usuario participante en p_usuarios_participantes';
  END IF;

  -- Inicializar acumulador de minutos de cada participante a 0
  FOREACH v_current_user IN ARRAY p_usuarios_participantes LOOP
    v_user_loads := jsonb_set(v_user_loads, ARRAY[v_current_user::text], '0'::jsonb, true);
  END LOOP;

  -- 2. Crear tabla temporal en memoria con las tareas candidatas
  -- Ordenación Greedy determinista: mayor duración primero, desempate por id
  CREATE TEMPORARY TABLE temp_tareas_a_repartir ON COMMIT DROP AS
  SELECT 
    t.id,
    t.titulo,
    t.tiempo_estimado_minutos,
    t.asignado_a
  FROM public.planificador_tareas t
  WHERE t.entorno_id = p_entorno_id
    AND t.estado = 'pendiente'
    AND (p_tarea_ids IS NULL OR t.id = ANY(p_tarea_ids))
  ORDER BY 
    t.tiempo_estimado_minutos DESC,
    t.id ASC;

  SELECT count(*), COALESCE(sum(tiempo_estimado_minutos), 0)
  INTO v_tareas_count, v_minutos_totales
  FROM temp_tareas_a_repartir;

  IF v_tareas_count = 0 THEN
    RAISE EXCEPTION 'No se encontraron tareas pendientes para repartir en este entorno';
  END IF;

  -- 3. Crear registro de sesión de reparto
  INSERT INTO public.planificador_repartos_sesiones (
    id,
    entorno_id,
    fecha_sesion,
    usuarios_participantes,
    minutos_totales,
    created_at
  ) VALUES (
    v_sesion_id,
    p_entorno_id,
    CURRENT_DATE,
    p_usuarios_participantes,
    v_minutos_totales,
    now()
  );

  -- 4. Iterar sobre las tareas ordenadas y asignar al usuario con menor tiempo acumulado
  FOR v_task IN SELECT * FROM temp_tareas_a_repartir LOOP
    v_min_load := 2147483647;
    v_selected_user := NULL;

    -- Localizar usuario con la menor carga actual
    FOREACH v_current_user IN ARRAY p_usuarios_participantes LOOP
      v_current_load := (v_user_loads->>v_current_user::text)::INT;
      IF v_current_load < v_min_load THEN
        v_min_load := v_current_load;
        v_selected_user := v_current_user;
      END IF;
    END LOOP;

    -- Actualizar acumulador del usuario seleccionado
    v_user_loads := jsonb_set(
      v_user_loads,
      ARRAY[v_selected_user::text],
      to_jsonb(v_min_load + v_task.tiempo_estimado_minutos)
    );

    -- Determinar usuario inicial no nulo (para respetar la constraint NOT NULL de planificador_repartos_items)
    v_initial_user := COALESCE(v_task.asignado_a, v_selected_user);

    -- 5. Insertar ítem de reparto
    INSERT INTO public.planificador_repartos_items (
      id,
      sesion_id,
      tarea_id,
      usuario_asignado_inicial,
      usuario_asignado_final,
      tiempo_minutos
    ) VALUES (
      gen_random_uuid(),
      v_sesion_id,
      v_task.id,
      v_initial_user,
      v_selected_user,
      v_task.tiempo_estimado_minutos
    );

    -- 6. Actualizar asignación de la tarea en planificador_tareas
    UPDATE public.planificador_tareas
    SET 
      asignado_a = v_selected_user,
      updated_at = now()
    WHERE id = v_task.id;

    -- Agregar al log de ítems retornados
    v_items_inserted := v_items_inserted || jsonb_build_object(
      'tarea_id', v_task.id,
      'titulo', v_task.titulo,
      'minutos', v_task.tiempo_estimado_minutos,
      'asignado_a', v_selected_user
    );
  END LOOP;

  -- 7. Retornar resultado estructurado
  RETURN jsonb_build_object(
    'sesion_id', v_sesion_id,
    'entorno_id', p_entorno_id,
    'tareas_repartidas', v_tareas_count,
    'minutos_totales', v_minutos_totales,
    'cargas_finales_usuarios', v_user_loads,
    'items', v_items_inserted
  );
END;
$$;

COMMENT ON FUNCTION public.planificador_ejecutar_reparto_equitativo IS 
'Ejecuta el algoritmo Greedy de reparto equitativo de tareas pendientes entre miembros del entorno e inserta la sesión y sus ítems.';

-- Permisos de ejecución
GRANT EXECUTE ON FUNCTION public.planificador_ejecutar_reparto_equitativo TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 2. FUNCIONES RPC PARA LA EDGE FUNCTION: RECORDATORIOS DIARIOS
-- ------------------------------------------------------------------------------

-- 2.1. Cumpleaños a notificar (exactamente hoy, en 3 días, en 7 días o en 14 días)
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
  SELECT 
    e.entorno_id,
    e.id AS evento_id,
    COALESCE(e.persona_cumpleanos, e.titulo) AS persona_cumpleanos,
    e.ideas_regalo,
    v.dias AS dias_restantes
  FROM public.planificador_eventos e
  CROSS JOIN (VALUES (0), (3), (7), (14)) AS v(dias)
  WHERE e.tipo = 'cumpleanos'
    AND EXTRACT(MONTH FROM e.fecha_inicio) = EXTRACT(MONTH FROM (CURRENT_DATE + (v.dias || ' days')::interval))
    AND EXTRACT(DAY FROM e.fecha_inicio) = EXTRACT(DAY FROM (CURRENT_DATE + (v.dias || ' days')::interval));
$$;

COMMENT ON FUNCTION public.planificador_obtener_cumpleanos_recordatorios IS 
'Retorna los eventos de cumpleaños cuyo día y mes coinciden exactamente con hoy, en 3 días, 7 días o 14 días.';

GRANT EXECUTE ON FUNCTION public.planificador_obtener_cumpleanos_recordatorios TO authenticated, service_role;


-- 2.2. Tareas que vencen hoy con responsable asignado y no completadas
CREATE OR REPLACE FUNCTION public.planificador_obtener_tareas_hoy()
RETURNS TABLE (
  entorno_id UUID,
  tarea_id UUID,
  titulo TEXT,
  tiempo_estimado_minutos INT,
  asignado_a UUID
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    t.entorno_id,
    t.id AS tarea_id,
    t.titulo,
    t.tiempo_estimado_minutos,
    t.asignado_a
  FROM public.planificador_tareas t
  WHERE t.fecha_limite::DATE = CURRENT_DATE
    AND t.estado != 'completada'
    AND t.asignado_a IS NOT NULL;
$$;

COMMENT ON FUNCTION public.planificador_obtener_tareas_hoy IS 
'Retorna las tareas pendientes o en progreso cuya fecha_limite es el día de hoy y tienen un usuario asignado.';

GRANT EXECUTE ON FUNCTION public.planificador_obtener_tareas_hoy TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3. AUTOMATIZACIÓN CRON: INVOCACIÓN DIARIA A LAS 08:00 AM UTC (pg_cron + pg_net)
-- ------------------------------------------------------------------------------
-- Requiere habilitar las extensiones pg_cron y pg_net en Supabase Dashboard.
-- Invoca la Edge Function "enviar-recordatorios" pasando la Service Role Key.
-- ------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Desprogramar trabajo previo si existiese con el mismo nombre para idempotencia
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'enviar-recordatorios-diarios-08am') THEN
    PERFORM cron.unschedule('enviar-recordatorios-diarios-08am');
  END IF;
END $$;

-- Programar ejecución a las 08:00 AM UTC todos los días (0 8 * * *)
-- NOTA: Reemplazar [PROJECT_REF] y [SUPABASE_SERVICE_ROLE_KEY] con los valores del proyecto.
SELECT cron.schedule(
  'enviar-recordatorios-diarios-08am',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url := 'https://[PROJECT_REF].supabase.co/functions/v1/enviar-recordatorios',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer [SUPABASE_SERVICE_ROLE_KEY]'
    ),
    body := jsonb_build_object(
      'source', 'pg_cron',
      'scheduled_at', now()
    ),
    timeout_milliseconds := 30000
  ) AS request_id;
  $$
);
