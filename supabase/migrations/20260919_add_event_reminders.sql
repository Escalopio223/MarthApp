-- ==============================================================================
-- Migración: Soporte de Recordatorios Programados para Eventos del Planificador
-- Fecha: 2026-09-19
-- ==============================================================================
-- Añade la columna JSONB 'recordatorios' a la tabla 'planificador_eventos'
-- para almacenar recordatorios programados con antelación y horas fijas o ciclo 8h,
-- idéntico al sistema de recordatorios de tareas.

ALTER TABLE public.planificador_eventos 
ADD COLUMN IF NOT EXISTS recordatorios JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.planificador_eventos.recordatorios IS 
'Lista de recordatorios programados en formato JSONB con fecha, hora opcional y estado de envío';
