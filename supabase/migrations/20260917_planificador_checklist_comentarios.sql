-- ==============================================================================
-- MIGRACIÓN SUPABASE: ACTUALIZACIÓN PLANIFICADOR (SUBTAREAS / CHECKLIST Y COMENTARIOS)
-- Fecha: 2026-09-17
-- ==============================================================================
-- 1. Actualizar restricción para permitir tareas sin estimación de tiempo (0 minutos)
ALTER TABLE public.planificador_tareas 
  DROP CONSTRAINT IF EXISTS planificador_tareas_tiempo_estimado_minutos_check;

ALTER TABLE public.planificador_tareas 
  ADD CONSTRAINT planificador_tareas_tiempo_estimado_minutos_check 
  CHECK (tiempo_estimado_minutos >= 0);

ALTER TABLE public.planificador_tareas 
  ALTER COLUMN tiempo_estimado_minutos SET DEFAULT 0;

-- 2. Añadir columnas JSONB para subtareas (checklist) y comentarios en planificador_tareas
ALTER TABLE public.planificador_tareas 
  ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.planificador_tareas 
  ADD COLUMN IF NOT EXISTS comentarios JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 3. Añadir columna JSONB para subtareas (checklist) en planificador_eventos
ALTER TABLE public.planificador_eventos 
  ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 4. Garantizar REPLICA IDENTITY FULL y suscripción a Realtime
ALTER TABLE public.planificador_tareas REPLICA IDENTITY FULL;
ALTER TABLE public.planificador_eventos REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_tareas;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.planificador_eventos;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END;
$$;
