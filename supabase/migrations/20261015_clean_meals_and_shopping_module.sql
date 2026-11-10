-- Migration: 20261015_clean_meals_and_shopping_module.sql
-- Módulo Minimalista de Comidas (Menú Semanal), Catálogo de Platos y Lista de la Compra

-- 1. Tabla de Platos (Dishes)
CREATE TABLE IF NOT EXISTS public.dishes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id UUID NOT NULL REFERENCES public.environments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    default_servings INT DEFAULT 2,
    ingredients JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array de strings simples: ["Pechuga de pollo", "Tomate frito"]
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices para búsqueda rápida en el catálogo
CREATE INDEX IF NOT EXISTS idx_dishes_env ON public.dishes(environment_id);
CREATE INDEX IF NOT EXISTS idx_dishes_name ON public.dishes(environment_id, lower(name));

-- 2. Tabla de Ranuras del Menú Semanal (Weekly Menu Slots)
-- Almuerzo y Cena por día del calendario
CREATE TABLE IF NOT EXISTS public.weekly_menu_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id UUID NOT NULL REFERENCES public.environments(id) ON DELETE CASCADE,
    slot_date DATE NOT NULL, -- Fecha específica (ej. 2026-11-10)
    meal_type TEXT NOT NULL CHECK (meal_type IN ('lunch', 'dinner')),
    dish_id UUID REFERENCES public.dishes(id) ON DELETE SET NULL,
    custom_dish_name TEXT, -- Por si el usuario apunta algo rápido sin plato guardado
    servings_note TEXT, -- Opcional: "4 rac.", "2 días", etc.
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_env_date_meal UNIQUE (environment_id, slot_date, meal_type)
);

CREATE INDEX IF NOT EXISTS idx_menu_slots_env_date ON public.weekly_menu_slots(environment_id, slot_date);

-- 3. Tabla de Ítems de la Lista de la Compra (Shopping Items)
CREATE TABLE IF NOT EXISTS public.shopping_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id UUID NOT NULL REFERENCES public.environments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_checked BOOLEAN NOT NULL DEFAULT false,
    category_or_source TEXT, -- Nombre del plato de origen (ej. "Pollo al curry") o categoría manual ("Limpieza", "Fruta")
    dish_id UUID REFERENCES public.dishes(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_shopping_items_env ON public.shopping_items(environment_id, is_checked);

-- RLS (Row Level Security)
ALTER TABLE public.dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_menu_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_items ENABLE ROW LEVEL SECURITY;

-- Helper función o policy estándar: Acceso si es miembro del entorno
CREATE POLICY dishes_env_member_policy ON public.dishes
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.environment_members em
            WHERE em.environment_id = dishes.environment_id
            AND em.user_id = auth.uid()
        )
    );

CREATE POLICY menu_slots_env_member_policy ON public.weekly_menu_slots
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.environment_members em
            WHERE em.environment_id = weekly_menu_slots.environment_id
            AND em.user_id = auth.uid()
        )
    );

CREATE POLICY shopping_items_env_member_policy ON public.shopping_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.environment_members em
            WHERE em.environment_id = shopping_items.environment_id
            AND em.user_id = auth.uid()
        )
    );
