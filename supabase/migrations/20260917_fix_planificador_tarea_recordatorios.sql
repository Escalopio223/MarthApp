-- ============================================================================
-- MIGRACIÓN: CORRECCIÓN Y ESPECIFICACIÓN EXACTA DE PLANIFICADOR_TAREA_RECORDATORIOS
-- ============================================================================
-- Se establece el modelo definitivo para recordatorios basados en fecha y hora opcional,
-- con soporte para múltiples recordatorios por tarea y ciclo recurrente de 8h para
-- recordatorios sin hora fija.

CREATE TABLE IF NOT EXISTS public.planificador_tarea_recordatorios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarea_id UUID NOT NULL REFERENCES public.planificador_tareas(id) ON DELETE CASCADE,
    fecha_notificacion DATE NOT NULL,
    hora_notificacion TIME NULL,
    enviado BOOLEAN NOT NULL DEFAULT false,
    ultimo_envio_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Si la tabla ya existía con estructuras previas, asegurar que todos los campos requeridos coincidan:
DO $$
BEGIN
    -- Asegurar columna fecha_notificacion
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'fecha_notificacion'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        ADD COLUMN fecha_notificacion DATE NOT NULL DEFAULT CURRENT_DATE;
    END IF;

    -- Asegurar columna hora_notificacion
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'hora_notificacion'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        ADD COLUMN hora_notificacion TIME NULL;
    END IF;

    -- Asegurar columna enviado
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'enviado'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        ADD COLUMN enviado BOOLEAN NOT NULL DEFAULT false;
    END IF;

    -- Asegurar columna ultimo_envio_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'ultimo_envio_at'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        ADD COLUMN ultimo_envio_at TIMESTAMPTZ NULL;
    END IF;

    -- Asegurar columna created_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    END IF;

    -- Eliminar columnas obsoletas no compatibles
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'planificador_tarea_recordatorios' 
          AND column_name = 'antelacion_minutos'
    ) THEN
        ALTER TABLE public.planificador_tarea_recordatorios 
        DROP COLUMN antelacion_minutos CASCADE;
    END IF;
END $$;

COMMENT ON TABLE public.planificador_tarea_recordatorios IS 
'Recordatorios programables por tarea con fecha, hora opcional y ciclo de repetición cada 8h';

-- ------------------------------------------------------------------------------
-- Índices optimizados para consultas de alta concurrencia y cron jobs
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_tarea_id 
    ON public.planificador_tarea_recordatorios (tarea_id);

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_escaneo 
    ON public.planificador_tarea_recordatorios (fecha_notificacion, hora_notificacion, enviado);

CREATE INDEX IF NOT EXISTS idx_planificador_recordatorios_ciclo_8h 
    ON public.planificador_tarea_recordatorios (fecha_notificacion, ultimo_envio_at) 
    WHERE hora_notificacion IS NULL;

-- ------------------------------------------------------------------------------
-- Helper de seguridad: validación de membresía en el entorno (environment_members / entorno_usuarios)
-- ------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------
-- Seguridad RLS (Row Level Security)
-- ------------------------------------------------------------------------------
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
