-- ============================================================================
-- MIGRACIÓN: Nuevos campos de metadatos y ordenación en listas compartidas de ocio
-- Fecha: 2026-09-15
-- ============================================================================

-- Añadir año de lanzamiento
alter table public.leisure_shared_list_items 
  add column if not exists year text;

-- Añadir nota o puntuación normalizada (0.0 - 10.0)
alter table public.leisure_shared_list_items 
  add column if not exists rating numeric;

-- Añadir lista de géneros para filtrado
alter table public.leisure_shared_list_items 
  add column if not exists genres text[] default '{}';

-- Añadir posición u orden manual personalizado para drag & drop
alter table public.leisure_shared_list_items 
  add column if not exists custom_order integer default 0;

-- Índice para consultas ordenadas por custom_order
create index if not exists idx_leisure_shared_list_items_order
  on public.leisure_shared_list_items (list_id, custom_order);
