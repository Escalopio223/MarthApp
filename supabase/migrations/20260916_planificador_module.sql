-- ==============================================================================
-- MÓDULO PLANIFICADOR: TABLAS RESTANTES, ÍNDICES Y POLÍTICAS RLS (PostgreSQL 15+)
-- ==============================================================================

-- 1. TABLA: planificador_tareas
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_tareas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  proyecto_id UUID NULL REFERENCES public.planificador_proyectos(id) ON DELETE SET NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT NULL,
  fecha_limite TIMESTAMPTZ NULL,
  asignado_a UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  tiempo_estimado_minutos INTEGER NOT NULL DEFAULT 15 CHECK (tiempo_estimado_minutos > 0),
  estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en_progreso', 'completada')),
  checklist JSONB NOT NULL DEFAULT '[]'::jsonb,
  completada_por UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  completada_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. TABLA: planificador_eventos
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
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TABLA: planificador_repartos_sesiones
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_repartos_sesiones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  fecha_sesion DATE NOT NULL DEFAULT CURRENT_DATE,
  usuarios_participantes UUID[] NOT NULL,
  minutos_totales INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TABLA: planificador_repartos_items
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.planificador_repartos_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id UUID NOT NULL REFERENCES public.planificador_repartos_sesiones(id) ON DELETE CASCADE,
  tarea_id UUID NOT NULL REFERENCES public.planificador_tareas(id) ON DELETE CASCADE,
  usuario_asignado_inicial UUID NOT NULL REFERENCES auth.users(id),
  usuario_asignado_final UUID NOT NULL REFERENCES auth.users(id),
  tiempo_minutos INTEGER NOT NULL CHECK (tiempo_minutos > 0)
);

-- 5. TABLA: usuario_fcm_tokens
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuario_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entorno_id UUID NOT NULL REFERENCES public.entornos(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  dispositivo_info TEXT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- ÍNDICES RELACIONALES
-- ------------------------------------------------------------------------------

-- planificador_proyectos (entorno_id)
CREATE INDEX IF NOT EXISTS idx_planificador_proyectos_entorno_id 
  ON public.planificador_proyectos (entorno_id);

-- planificador_tareas (entorno_id, proyecto_id, asignado_a, fecha_limite)
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

-- planificador_eventos (entorno_id, fechas)
CREATE INDEX IF NOT EXISTS idx_planificador_eventos_entorno_id 
  ON public.planificador_eventos (entorno_id);
CREATE INDEX IF NOT EXISTS idx_planificador_eventos_fechas 
  ON public.planificador_eventos (entorno_id, fecha_inicio, fecha_fin);

-- planificador_repartos_sesiones (entorno_id)
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_sesiones_entorno_id 
  ON public.planificador_repartos_sesiones (entorno_id);

-- planificador_repartos_items (sesion_id, tarea_id, usuario_asignado_final)
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_sesion_id 
  ON public.planificador_repartos_items (sesion_id);
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_tarea_id 
  ON public.planificador_repartos_items (tarea_id);
CREATE INDEX IF NOT EXISTS idx_planificador_repartos_items_usuario 
  ON public.planificador_repartos_items (usuario_asignado_final);

-- usuario_fcm_tokens (user_id, entorno_id)
CREATE INDEX IF NOT EXISTS idx_usuario_fcm_tokens_user_id 
  ON public.usuario_fcm_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_usuario_fcm_tokens_entorno_id 
  ON public.usuario_fcm_tokens (entorno_id);

-- ------------------------------------------------------------------------------
-- HABILITACIÓN DE ROW LEVEL SECURITY (RLS) EN LAS 6 TABLAS
-- ------------------------------------------------------------------------------
ALTER TABLE public.planificador_proyectos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_tareas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_repartos_sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planificador_repartos_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: planificador_proyectos
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "proyectos_select" ON public.planificador_proyectos;
CREATE POLICY "proyectos_select" ON public.planificador_proyectos
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_proyectos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "proyectos_insert" ON public.planificador_proyectos;
CREATE POLICY "proyectos_insert" ON public.planificador_proyectos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_proyectos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "proyectos_update" ON public.planificador_proyectos;
CREATE POLICY "proyectos_update" ON public.planificador_proyectos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_proyectos.entorno_id
        AND eu.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_proyectos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "proyectos_delete" ON public.planificador_proyectos;
CREATE POLICY "proyectos_delete" ON public.planificador_proyectos
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_proyectos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: planificador_tareas
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "tareas_select" ON public.planificador_tareas;
CREATE POLICY "tareas_select" ON public.planificador_tareas
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_tareas.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tareas_insert" ON public.planificador_tareas;
CREATE POLICY "tareas_insert" ON public.planificador_tareas
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_tareas.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tareas_update" ON public.planificador_tareas;
CREATE POLICY "tareas_update" ON public.planificador_tareas
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_tareas.entorno_id
        AND eu.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_tareas.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "tareas_delete" ON public.planificador_tareas;
CREATE POLICY "tareas_delete" ON public.planificador_tareas
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_tareas.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: planificador_eventos
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "eventos_select" ON public.planificador_eventos;
CREATE POLICY "eventos_select" ON public.planificador_eventos
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_eventos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "eventos_insert" ON public.planificador_eventos;
CREATE POLICY "eventos_insert" ON public.planificador_eventos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_eventos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "eventos_update" ON public.planificador_eventos;
CREATE POLICY "eventos_update" ON public.planificador_eventos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_eventos.entorno_id
        AND eu.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_eventos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "eventos_delete" ON public.planificador_eventos;
CREATE POLICY "eventos_delete" ON public.planificador_eventos
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_eventos.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: planificador_repartos_sesiones
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "repartos_sesiones_select" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_select" ON public.planificador_repartos_sesiones
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_repartos_sesiones.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_sesiones_insert" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_insert" ON public.planificador_repartos_sesiones
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_repartos_sesiones.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_sesiones_update" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_update" ON public.planificador_repartos_sesiones
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_repartos_sesiones.entorno_id
        AND eu.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_repartos_sesiones.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_sesiones_delete" ON public.planificador_repartos_sesiones;
CREATE POLICY "repartos_sesiones_delete" ON public.planificador_repartos_sesiones
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = planificador_repartos_sesiones.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: planificador_repartos_items
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "repartos_items_select" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_select" ON public.planificador_repartos_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      JOIN public.entorno_usuarios eu ON eu.entorno_id = s.entorno_id
      WHERE s.id = planificador_repartos_items.sesion_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_items_insert" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_insert" ON public.planificador_repartos_items
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      JOIN public.entorno_usuarios eu ON eu.entorno_id = s.entorno_id
      WHERE s.id = planificador_repartos_items.sesion_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_items_update" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_update" ON public.planificador_repartos_items
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      JOIN public.entorno_usuarios eu ON eu.entorno_id = s.entorno_id
      WHERE s.id = planificador_repartos_items.sesion_id
        AND eu.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      JOIN public.entorno_usuarios eu ON eu.entorno_id = s.entorno_id
      WHERE s.id = planificador_repartos_items.sesion_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "repartos_items_delete" ON public.planificador_repartos_items;
CREATE POLICY "repartos_items_delete" ON public.planificador_repartos_items
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.planificador_repartos_sesiones s
      JOIN public.entorno_usuarios eu ON eu.entorno_id = s.entorno_id
      WHERE s.id = planificador_repartos_items.sesion_id
        AND eu.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- POLÍTICAS RLS: usuario_fcm_tokens (Acceso exclusivo auth.uid() = user_id)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "fcm_tokens_select" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_select" ON public.usuario_fcm_tokens
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "fcm_tokens_insert" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_insert" ON public.usuario_fcm_tokens
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = usuario_fcm_tokens.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "fcm_tokens_update" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_update" ON public.usuario_fcm_tokens
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = usuario_fcm_tokens.entorno_id
        AND eu.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "fcm_tokens_delete" ON public.usuario_fcm_tokens;
CREATE POLICY "fcm_tokens_delete" ON public.usuario_fcm_tokens
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
