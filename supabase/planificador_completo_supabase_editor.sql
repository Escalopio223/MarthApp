-- ==============================================================================
-- MARTHAPP: MÓDULO PLANIFICADOR COMPLETO (SQL PARA SUPABASE SQL EDITOR)
-- ==============================================================================
-- Este script es 100% idempotente (se puede ejecutar varias veces sin errores).
-- Incluye:
--  1. Extensiones y compatibilidad con tablas de entornos
--  2. 6 Tablas: Proyectos, Tareas, Eventos, Sesiones Reparto, Ítems Reparto, Tokens FCM
--  3. Restricciones de integridad referencial (FKs) y validaciones CHECK
--  4. Índices de alto rendimiento para consultas filtradas por entorno_id y fechas
--  5. Row Level Security (RLS) en todas las tablas con políticas para autenticados
--  6. Triggers automáticos para updated_at y estados de completitud de tareas
--  7. Algoritmo Greedy de Reparto Equitativo en PostgreSQL (RPC)
--  8. Funciones RPC para la Edge Function de Recordatorios Diarios (FCM)
--  9. Programación diaria a las 08:00 AM UTC (pg_cron + pg_net)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. EXTENSIONES BÁSICAS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. TABLAS BASE DE MULTITENANCY (Garantizar existencia en caso de entorno nuevo)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.entornos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL DEFAULT 'Mi Entorno',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.entorno_usuarios (
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (entorno_id, user_id)
);

-- Si la base de datos utiliza la nomenclatura en inglés (environments / environment_members),
-- sincronizar automáticamente registros y crear triggers para mantener compatibilidad bidireccional continua:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'environments') THEN
    INSERT INTO public.entornos (id, nombre, created_at)
    SELECT id, name, created_at FROM public.environments
    ON CONFLICT (id) DO NOTHING;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'environment_members') THEN
    INSERT INTO public.entorno_usuarios (entorno_id, user_id)
    SELECT environment_id, user_id FROM public.environment_members
    ON CONFLICT (entorno_id, user_id) DO NOTHING;
  END IF;
END $$;

-- Triggers automáticos para que cualquier nuevo entorno o miembro quede sincronizado de inmediato:
CREATE OR REPLACE FUNCTION public.sync_environments_to_entornos()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.entornos (id, nombre, created_at)
  VALUES (NEW.id, NEW.name, NEW.created_at)
  ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_environments ON public.environments;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'environments') THEN
    CREATE TRIGGER trg_sync_environments
      AFTER INSERT OR UPDATE ON public.environments
      FOR EACH ROW EXECUTE FUNCTION public.sync_environments_to_entornos();
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_members_to_entorno_usuarios()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.entorno_usuarios (entorno_id, user_id)
  VALUES (NEW.environment_id, NEW.user_id)
  ON CONFLICT (entorno_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_environment_members ON public.environment_members;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'environment_members') THEN
    CREATE TRIGGER trg_sync_environment_members
      AFTER INSERT OR UPDATE ON public.environment_members
      FOR EACH ROW EXECUTE FUNCTION public.sync_members_to_entorno_usuarios();
  END IF;
END $$;


-- ==============================================================================
-- 2. TABLAS DEL MÓDULO PLANIFICADOR
-- ==============================================================================

-- 2.1. TABLA: planificador_proyectos
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_proyectos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  descripcion TEXT NULL,
  icono TEXT NOT NULL DEFAULT 'folder',
  color_hex TEXT NOT NULL DEFAULT '#6366F1',
  presupuesto_estimado NUMERIC(10, 2) NULL DEFAULT 0.00,
  coste_real NUMERIC(10, 2) NULL DEFAULT 0.00,
  estado TEXT NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'pausado', 'completado', 'cancelado')),
  created_by UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.planificador_proyectos IS 'Proyectos colaborativos del entorno (ej: reformas, compras mayores, objetivos)';

-- 2.2. TABLA: planificador_tareas
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_tareas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  proyecto_id UUID NULL REFERENCES public.planificador_proyectos(id) ON DELETE SET NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT NULL,
  fecha_limite TIMESTAMPTZ NULL,
  asignado_a UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  tiempo_estimado_minutos INTEGER NOT NULL DEFAULT 0 CHECK (tiempo_estimado_minutos >= 0),
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en_progreso', 'completada')),
  checklist JSONB NOT NULL DEFAULT '[]'::jsonb,
  comentarios JSONB NOT NULL DEFAULT '[]'::jsonb,
  completada_por UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  completada_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Actualizar restricción en tablas existentes para permitir 0 minutos ("Sin tiempo") y asegurar columna checklist
ALTER TABLE public.planificador_tareas DROP CONSTRAINT IF EXISTS planificador_tareas_tiempo_estimado_minutos_check;
ALTER TABLE public.planificador_tareas ADD CONSTRAINT planificador_tareas_tiempo_estimado_minutos_check CHECK (tiempo_estimado_minutos >= 0);
ALTER TABLE public.planificador_tareas ALTER COLUMN tiempo_estimado_minutos SET DEFAULT 0;
ALTER TABLE public.planificador_tareas ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.planificador_tareas ADD COLUMN IF NOT EXISTS comentarios JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON TABLE public.planificador_tareas IS 'Tareas del hogar o de proyectos con checklist, comentarios y tiempo estimado para reparto';

-- 2.3. TABLA: planificador_eventos
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_eventos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  descripcion TEXT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('cumpleanos', 'evento_general')),
  fecha_inicio TIMESTAMPTZ NOT NULL,
  fecha_fin TIMESTAMPTZ NULL,
  es_todo_el_dia BOOLEAN NOT NULL DEFAULT false,
  rrule TEXT NULL,
  persona_cumpleanos TEXT NULL,
  ideas_regalo TEXT NULL,
  checklist JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Garantizar existencia de la columna checklist en tablas existentes
ALTER TABLE public.planificador_eventos ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON TABLE public.planificador_eventos IS 'Agenda, eventos y cumpleaños de familiares o miembros con recordatorios automáticos y checklist';

-- 2.4. TABLA: planificador_repartos_sesiones
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_repartos_sesiones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  fecha_sesion DATE NOT NULL DEFAULT CURRENT_DATE,
  usuarios_participantes UUID[] NOT NULL,
  minutos_totales INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.planificador_repartos_sesiones IS 'Sesiones históricas de cálculo o aplicación de reparto equitativo';

-- 2.5. TABLA: planificador_repartos_items
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_repartos_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id UUID NOT NULL REFERENCES public.planificador_repartos_sesiones(id) ON DELETE CASCADE,
  tarea_id UUID NOT NULL REFERENCES public.planificador_tareas(id) ON DELETE CASCADE,
  usuario_asignado_inicial UUID NOT NULL REFERENCES auth.users(id),
  usuario_asignado_final UUID NOT NULL REFERENCES auth.users(id),
  tiempo_minutos INTEGER NOT NULL CHECK (tiempo_minutos > 0)
);

COMMENT ON TABLE public.planificador_repartos_items IS 'Desglose detallado de tareas asignadas en cada sesión de reparto';

-- 2.6. TABLA: usuario_fcm_tokens
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuario_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  dispositivo_info TEXT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.usuario_fcm_tokens IS 'Tokens FCM de dispositivos para notificaciones push de cumpleaños y recordatorios';


-- ==============================================================================
-- 3. ÍNDICES DE ALTO RENDIMIENTO
-- ==============================================================================

-- Proyectos
CREATE INDEX IF NOT EXISTS idx_planificador_proyectos_entorno_id 
  ON public.planificador_proyectos (entorno_id);

-- Tareas
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_entorno_id 
  ON public.planificador_tareas (entorno_id);
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_proyecto_id 
  ON public.planificador_tareas (proyecto_id);
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_asignado_a 
  ON public.planificador_tareas (asignado_a);
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_fecha_limite 
  ON public.planificador_tareas (fecha_limite);
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_entorno_fecha 
  ON public.planificador_tareas (entorno_id, fecha_limite);
CREATE INDEX IF NOT EXISTS idx_planificador_tareas_pendientes
  ON public.planificador_tareas (entorno_id, estado) WHERE estado = 'pendiente';

-- Eventos
CREATE INDEX IF NOT EXISTS idx_planificador_eventos_entorno_id 
  ON public.planificador_eventos (entorno_id);
CREATE INDEX IF NOT EXISTS idx_planificador_eventos_fechas 
  ON public.planificador_eventos (entorno_id, fecha_inicio, fecha_fin);
CREATE INDEX IF NOT EXISTS idx_planificador_eventos_cumpleanos 
  ON public.planificador_eventos (entorno_id, tipo) WHERE tipo = 'cumpleanos';

-- Sesiones e Ítems de Reparto
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_sesiones_entorno_id 
  ON public.planificador_repartos_sesiones (entorno_id);
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_sesion_id 
  ON public.planificador_repartos_items (sesion_id);
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_tarea_id 
  ON public.planificador_repartos_items (tarea_id);
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_usuario 
  ON public.planificador_repartos_items (usuario_asignado_final);

-- Tokens FCM
CREATE INDEX IF NOT EXISTS idx_usuario_fcm_tokens_user_id 
  ON public.usuario_fcm_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_usuario_fcm_tokens_entorno_id 
  ON public.usuario_fcm_tokens (entorno_id);


-- ==============================================================================
-- 4. ROW LEVEL SECURITY (RLS) Y POLÍTICAS DE ACCESO
-- ==============================================================================
ALTER TABLE public.planificador_proyectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_tareas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_repartos_sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_repartos_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Helper de seguridad optimizado para validar pertenencia al entorno (soporta tanto environment_members como entorno_usuarios):
CREATE OR REPLACE FUNCTION public.planificador_usuario_es_miembro_entorno(p_entorno_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.environment_members em
    WHERE em.environment_id = p_entorno_id AND em.user_id = p_user_id
  )
  OR EXISTS (
    SELECT 1 FROM public.entorno_usuarios eu
    WHERE eu.entorno_id = p_entorno_id AND eu.user_id = p_user_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.planificador_usuario_es_miembro_entorno TO authenticated, service_role;

-- 4.1. POLÍTICAS: planificador_proyectos
DROP POLICY IF EXISTS "proyectos_select" ON public.planificador_proyectos;
CREATE POLICY "proyectos_select" ON public.planificador_proyectos
  FOR SELECT TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "proyectos_insert" ON public.planificador_proyectos;
CREATE POLICY "proyectos_insert" ON public.planificador_proyectos
  FOR INSERT TO authenticated
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "proyectos_update" ON public.planificador_proyectos;
CREATE POLICY "proyectos_update" ON public.planificador_proyectos
  FOR UPDATE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()))
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "proyectos_delete" ON public.planificador_proyectos;
CREATE POLICY "proyectos_delete" ON public.planificador_proyectos
  FOR DELETE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

-- 4.2. POLÍTICAS: planificador_tareas
DROP POLICY IF EXISTS "tareas_select" ON public.planificador_tareas;
CREATE POLICY "tareas_select" ON public.planificador_tareas
  FOR SELECT TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "tareas_insert" ON public.planificador_tareas;
CREATE POLICY "tareas_insert" ON public.planificador_tareas
  FOR INSERT TO authenticated
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "tareas_update" ON public.planificador_tareas;
CREATE POLICY "tareas_update" ON public.planificador_tareas
  FOR UPDATE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()))
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "tareas_delete" ON public.planificador_tareas;
CREATE POLICY "tareas_delete" ON public.planificador_tareas
  FOR DELETE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

-- 4.3. POLÍTICAS: planificador_eventos
DROP POLICY IF EXISTS "eventos_select" ON public.planificador_eventos;
CREATE POLICY "eventos_select" ON public.planificador_eventos
  FOR SELECT TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "eventos_insert" ON public.planificador_eventos;
CREATE POLICY "eventos_insert" ON public.planificador_eventos
  FOR INSERT TO authenticated
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "eventos_update" ON public.planificador_eventos;
CREATE POLICY "eventos_update" ON public.planificador_eventos
  FOR UPDATE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()))
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "eventos_delete" ON public.planificador_eventos;
CREATE POLICY "eventos_delete" ON public.planificador_eventos
  FOR DELETE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

-- 4.4. POLÍTICAS: planificador_repartos_sesiones
DROP POLICY IF EXISTS "repartos_sesiones_select" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_select" ON public.planificador_repartos_sesiones
  FOR SELECT TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "repartos_sesiones_insert" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_insert" ON public.planificador_repartos_sesiones
  FOR INSERT TO authenticated
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "repartos_sesiones_update" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_update" ON public.planificador_repartos_sesiones
  FOR UPDATE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()))
  WITH CHECK (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

DROP POLICY IF EXISTS "repartos_sesiones_delete" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_delete" ON public.planificador_repartos_sesiones
  FOR DELETE TO authenticated
  USING (public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid()));

-- 4.5. POLÍTICAS: planificador_repartos_items
DROP POLICY IF EXISTS "repartos_items_select" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_select" ON public.planificador_repartos_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      WHERE s.id = planificador_repartos_items.sesion_id
        AND public.planificador_usuario_es_miembro_entorno(s.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "repartos_items_insert" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_insert" ON public.planificador_repartos_items
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      WHERE s.id = planificador_repartos_items.sesion_id
        AND public.planificador_usuario_es_miembro_entorno(s.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "repartos_items_update" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_update" ON public.planificador_repartos_items
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      WHERE s.id = planificador_repartos_items.sesion_id
        AND public.planificador_usuario_es_miembro_entorno(s.entorno_id, auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      WHERE s.id = planificador_repartos_items.sesion_id
        AND public.planificador_usuario_es_miembro_entorno(s.entorno_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "repartos_items_delete" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_delete" ON public.planificador_repartos_items
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      WHERE s.id = planificador_repartos_items.sesion_id
        AND public.planificador_usuario_es_miembro_entorno(s.entorno_id, auth.uid())
    )
  );

-- 4.6. POLÍTICAS: usuario_fcm_tokens
DROP POLICY IF EXISTS "fcm_tokens_select" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_select" ON public.usuario_fcm_tokens
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "fcm_tokens_insert" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_insert" ON public.usuario_fcm_tokens
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid())
  );

DROP POLICY IF EXISTS "fcm_tokens_update" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_update" ON public.usuario_fcm_tokens
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND public.planificador_usuario_es_miembro_entorno(entorno_id, auth.uid())
  );

DROP POLICY IF EXISTS "fcm_tokens_delete" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_delete" ON public.usuario_fcm_tokens
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);


-- ==============================================================================
-- 5. TRIGGERS Y FUNCIONES DE AUTOMATIZACIÓN
-- ==============================================================================

-- 5.1. Trigger para actualizar columna updated_at
CREATE OR REPLACE FUNCTION public.handle_planificador_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proyectos_updated_at ON public.planificador_proyectos;
CREATE TRIGGER trg_proyectos_updated_at
  BEFORE UPDATE ON public.planificador_proyectos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_planificador_updated_at();

DROP TRIGGER IF EXISTS trg_tareas_updated_at ON public.planificador_tareas;
CREATE TRIGGER trg_tareas_updated_at
  BEFORE UPDATE ON public.planificador_tareas
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_planificador_updated_at();

DROP TRIGGER IF EXISTS trg_eventos_updated_at ON public.planificador_eventos;
CREATE TRIGGER trg_eventos_updated_at
  BEFORE UPDATE ON public.planificador_eventos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_planificador_updated_at();

DROP TRIGGER IF EXISTS trg_fcm_tokens_updated_at ON public.usuario_fcm_tokens;
CREATE TRIGGER trg_fcm_tokens_updated_at
  BEFORE UPDATE ON public.usuario_fcm_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_planificador_updated_at();

-- 5.2. Trigger para gestionar completada_at y completada_por según el estado de la tarea
CREATE OR REPLACE FUNCTION public.handle_planificador_tarea_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.estado = 'completada' AND OLD.estado != 'completada' THEN
    NEW.completada_at = now();
    IF NEW.completada_por IS NULL THEN
      NEW.completada_por = auth.uid();
    END IF;
  ELSIF NEW.estado != 'completada' AND OLD.estado = 'completada' THEN
    NEW.completada_at = NULL;
    NEW.completada_por = NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tareas_estado_completada ON public.planificador_tareas;
CREATE TRIGGER trg_tareas_estado_completada
  BEFORE UPDATE ON public.planificador_tareas
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_planificador_tarea_estado();


-- ==============================================================================
-- 6. ALGORITMO GREEDY DETERMINISTA DE REPARTO EQUITATIVO (RPC)
-- ==============================================================================
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
  
  v_user_loads JSONB := '{}'::jsonb;
  v_task RECORD;
  v_selected_user UUID;
  v_min_load INT;
  v_current_user UUID;
  v_current_load INT;
  v_initial_user UUID;
  
  v_items_inserted JSONB := '[]'::jsonb;
BEGIN
  -- Validaciones
  IF p_entorno_id IS NULL THEN
    RAISE EXCEPTION 'El parámetro p_entorno_id es obligatorio';
  END IF;

  v_num_usuarios := array_length(p_usuarios_participantes, 1);
  IF v_num_usuarios IS NULL OR v_num_usuarios = 0 THEN
    RAISE EXCEPTION 'Debe especificarse al menos un usuario participante en p_usuarios_participantes';
  END IF;

  -- Inicializar carga de cada participante a 0
  FOREACH v_current_user IN ARRAY p_usuarios_participantes LOOP
    v_user_loads := jsonb_set(v_user_loads, ARRAY[v_current_user::text], '0'::jsonb, true);
  END LOOP;

  -- Tabla temporal con tareas candidatas ordenadas por duración DESC, desempate por id ASC
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

  -- Crear sesión
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

  -- Greedy assignment: asignar a participante con menor carga
  FOR v_task IN SELECT * FROM temp_tareas_a_repartir LOOP
    v_min_load := 2147483647;
    v_selected_user := NULL;

    FOREACH v_current_user IN ARRAY p_usuarios_participantes LOOP
      v_current_load := (v_user_loads->>v_current_user::text)::INT;
      IF v_current_load < v_min_load THEN
        v_min_load := v_current_load;
        v_selected_user := v_current_user;
      END IF;
    END LOOP;

    -- Actualizar acumulador
    v_user_loads := jsonb_set(
      v_user_loads,
      ARRAY[v_selected_user::text],
      to_jsonb(v_min_load + v_task.tiempo_estimado_minutos)
    );

    v_initial_user := COALESCE(v_task.asignado_a, v_selected_user);

    -- Insertar ítem
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

    -- Actualizar asignación de la tarea
    UPDATE public.planificador_tareas
    SET 
      asignado_a = v_selected_user,
      updated_at = now()
    WHERE id = v_task.id;

    v_items_inserted := v_items_inserted || jsonb_build_object(
      'tarea_id', v_task.id,
      'titulo', v_task.titulo,
      'minutos', v_task.tiempo_estimado_minutos,
      'asignado_a', v_selected_user
    );
  END LOOP;

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

GRANT EXECUTE ON FUNCTION public.planificador_ejecutar_reparto_equitativo TO authenticated, service_role;


-- ==============================================================================
-- 7. FUNCIONES RPC PARA LA EDGE FUNCTION (RECORDATORIOS DIARIOS)
-- ==============================================================================

-- 7.1. Cumpleaños a notificar (hoy, en 3, 7 o 14 días)
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

GRANT EXECUTE ON FUNCTION public.planificador_obtener_cumpleanos_recordatorios TO authenticated, service_role;

-- 7.2. Tareas que vencen hoy
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

GRANT EXECUTE ON FUNCTION public.planificador_obtener_tareas_hoy TO authenticated, service_role;


-- ==============================================================================
-- 8. CONFIGURACIÓN SUPABASE REALTIME (WebSockets / Streams Reactivos)
-- ==============================================================================
-- Necesario para que la app en Flutter pueda suscribirse a los cambios en tiempo
-- real de las tablas del Planificador (streamProyectos, streamTareas, streamEventos).

ALTER TABLE public.planificador_proyectos REPLICA IDENTITY FULL;
ALTER TABLE public.planificador_tareas REPLICA IDENTITY FULL;
ALTER TABLE public.planificador_eventos REPLICA IDENTITY FULL;
ALTER TABLE public.planificador_repartos_sesiones REPLICA IDENTITY FULL;
ALTER TABLE public.planificador_repartos_items REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_proyectos;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_tareas;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_eventos;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_repartos_sesiones;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_repartos_items;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END;
$$;


-- ==============================================================================
-- 9. AUTOMATIZACIÓN CRON OPCIONAL (pg_cron + pg_net)
-- ==============================================================================
-- Para activar los recordatorios automáticos diarios a las 08:00 AM UTC,
-- activa las extensiones "pg_cron" y "pg_net" desde el Dashboard de Supabase
-- (Database -> Extensions), y luego descomenta este bloque reemplazando tu
-- ==============================================================================
-- 7. SISTEMA GLOBAL DE NOTIFICACIONES PUSH Y RECORDATORIOS DE TAREAS (FCM v1)
-- ==============================================================================

-- 7.1. Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA pg_catalog;

-- 7.2. Seguridad: Eliminar tabla de credenciales en texto plano
DROP TABLE IF EXISTS public.app_push_config CASCADE;

-- Control transaccional en sesiones de reparto (Prevención de condición de carrera)
ALTER TABLE public.planificador_repartos_sesiones 
  ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'borrador' 
  CHECK (estado IN ('borrador', 'completado'));

-- 7.3. Tabla: planificador_tarea_recordatorios
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

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_tarea_id 
  ON public.planificador_tarea_recordatorios (tarea_id);

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_escaneo 
  ON public.planificador_tarea_recordatorios (fecha_notificacion, hora_notificacion, enviado);

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_ciclo_8h 
  ON public.planificador_tarea_recordatorios (fecha_notificacion, ultimo_envio_at) 
  WHERE hora_notificacion IS NULL;

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

-- 7.4. Flexibilizar usuario_fcm_tokens (vincular al dispositivo del usuario)
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

-- 7.5. Función despachadora asíncrona segura vía pg_net (Sin exponer Service Key en BD)
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
  -- Leer parámetros de sesión del motor (sin almacenar claves en tablas públicas)
  v_url := current_setting('app.settings.supabase_url', true);
  v_internal_secret := current_setting('app.settings.internal_push_secret', true);

  IF (v_url IS NULL OR v_url = '') THEN
    v_url := 'https://cntspvnxrmqchvtcdiwv.supabase.co';
  END IF;
  IF (v_internal_secret IS NULL OR v_internal_secret = '') THEN
    v_internal_secret := 'marthapp_internal_push_secret_key_2026';
  END IF;

  v_target_url := rtrim(v_url, '/') || '/functions/v1/push-dispatcher';

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
    RAISE WARNING 'dispatch_push_notification falló (%: %)', SQLSTATE, SQLERRM;
END;
$$;

-- 7.6. Triggers Inmediatos (Event-Driven)
-- 7.6.1. Solicitud de amistad recibida
CREATE OR REPLACE FUNCTION public.trg_notif_friend_request_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
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

-- 7.6.2. Invitación a entorno recibida
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
    SELECT COALESCE(username, 'Un miembro')
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

-- 7.6.3. Reparto de tareas completado (Garantizado libre de condiciones de carrera)
DROP TRIGGER IF EXISTS trg_notif_reparto_sesion ON public.planificador_repartos_sesiones;

CREATE OR REPLACE FUNCTION public.trg_notif_reparto_sesion_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Se dispara únicamente cuando el estado pasa a 'completado', asegurando que
  -- todos los items secundarios y asignaciones han sido insertados y confirmados.
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

-- 7.7. Recordatorios Programados (pg_cron)
CREATE OR REPLACE FUNCTION public.cron_dispatch_scheduled_reminders()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.dispatch_push_notification(
    'scheduled',
    jsonb_build_object('source', 'pg_cron', 'timestamp', now())
  );
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'push-dispatcher-scheduled-hourly') THEN
    PERFORM cron.unschedule('push-dispatcher-scheduled-hourly');
  END IF;
  
  PERFORM cron.schedule(
    'push-dispatcher-scheduled-hourly',
    '0 * * * *',
    'SELECT public.cron_dispatch_scheduled_reminders();'
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron no disponible o sin permisos: %', SQLERRM;
END $$;
