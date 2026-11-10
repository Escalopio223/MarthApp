-- Migration: 20261020_global_recipes_catalog.sql
-- Catálogo global de 1.500+ recetas reales con detección de electrodomésticos e ingredientes limpios

CREATE TABLE IF NOT EXISTS public.global_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_url TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    cuisine TEXT,                           -- País / estilo de cocina (ej. "Mexicana", "Italiana", "Española")
    category TEXT,                          -- Tipo de plato (ej. "Aperitivos", "Plato principal", "Postres")
    total_time_minutes INT,                 -- Tiempo total en minutos
    servings TEXT,                          -- Raciones o comensales (ej. "4 raciones")
    shopping_ingredients JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array de nombres limpios para lista de compra (ej. ["pechuga de pollo", "cebolla"])
    detailed_ingredients JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array original con cantidades exactas
    supported_appliances TEXT[] NOT NULL DEFAULT '{}',       -- Array indexado: 'airfryer', 'oven', 'microwave', 'stovetop'
    instructions JSONB NOT NULL DEFAULT '[]'::jsonb,         -- Pasos e información de cocción (temperatura, tiempo por aparato)
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de alto rendimiento para filtrado y búsqueda
CREATE INDEX IF NOT EXISTS idx_global_recipes_appliances ON public.global_recipes USING GIN (supported_appliances);
CREATE INDEX IF NOT EXISTS idx_global_recipes_shopping_ingredients ON public.global_recipes USING GIN (shopping_ingredients);
CREATE INDEX IF NOT EXISTS idx_global_recipes_cuisine ON public.global_recipes(cuisine);

-- Índice Full-Text Search en español sobre título y categoría
CREATE INDEX IF NOT EXISTS idx_global_recipes_title_fts ON public.global_recipes 
USING GIN (to_tsvector('spanish', coalesce(title, '') || ' ' || coalesce(cuisine, '') || ' ' || coalesce(category, '')));

-- Políticas RLS (Catálogo de lectura público para usuarios autenticados)
ALTER TABLE public.global_recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read global_recipes to all authenticated users"
    ON public.global_recipes
    FOR SELECT
    TO authenticated
    USING (true);

-- Permisos de inserción / upsert para el servicio / service_role
CREATE POLICY "Allow service role full access to global_recipes"
    ON public.global_recipes
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

