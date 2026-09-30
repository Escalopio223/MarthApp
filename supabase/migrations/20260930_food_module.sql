-- ==============================================================================
-- MIGRACIÓN: 20260930_food_module.sql
-- Módulo de Alimentación para MarthApp (Catálogo Colaborativo, Menús, Calendario y Compra)
-- ==============================================================================

-- 1. EXTENSIONES REQUERIDAS
-- ------------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";

-- 2. FUNCIÓN DE SEGURIDAD / MEMBRESÍA EN ENTORNO (SECURITY DEFINER & STABLE)
-- Evita recursión en políticas RLS y optimiza las comprobaciones de pertenencia
-- ------------------------------------------------------------------------------
create or replace function public.is_environment_member(target_env_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.environment_members
    where environment_id = target_env_id
      and user_id = auth.uid()
  );
$$;

comment on function public.is_environment_member(uuid) is 'Verifica de forma segura y directa si el usuario autenticado pertenece al entorno';

grant execute on function public.is_environment_member(uuid) to authenticated;

-- 3. TABLAS E INTEGRIDAD REFERENCIAL
-- ------------------------------------------------------------------------------

-- 3.1. Categorías de alimentos
create table if not exists public.food_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon_slug text not null unique check (
    icon_slug in ('dairy', 'fruit', 'vegetable', 'meat', 'fish', 'grain', 'bakery', 'snack', 'cleaning')
  ),
  created_at timestamp with time zone default now() not null
);

comment on table public.food_categories is 'Categorías taxonómicas estándar para ingredientes y lista de la compra';

-- 3.2. Recetas (Catálogo global y recetas caseras del entorno)
create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  country text not null default 'España',
  cuisine_type text not null default 'Mediterránea',
  prep_oven text null,
  prep_airfryer text null,
  prep_microwave text null,
  is_global boolean not null default true,
  environment_id uuid null references public.environments(id) on delete cascade,
  created_at timestamp with time zone default now() not null,
  constraint chk_recipe_scope check (
    (is_global = true and environment_id is null) or
    (is_global = false and environment_id is not null)
  )
);

comment on table public.recipes is 'Recetas culinarias del catálogo global o creadas de forma privada dentro de un entorno';

-- 3.3. Ingredientes de las recetas (normalizados en minúsculas)
create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  name text not null,
  category_id uuid not null references public.food_categories(id) on delete restrict,
  created_at timestamp with time zone default now() not null,
  constraint chk_ingredient_name_lowercase check (name = lower(name))
);

comment on table public.recipe_ingredients is 'Ingredientes normalizados en minúsculas categorizados por grupo alimentario';

-- 3.4. Favoritos de cocina del entorno (recetas o ingredientes frecuentes)
create table if not exists public.food_favorites (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  item_type text not null check (item_type in ('recipe', 'ingredient')),
  recipe_id uuid null references public.recipes(id) on delete cascade,
  ingredient_name text null,
  created_at timestamp with time zone default now() not null,
  constraint chk_food_favorite_target check (
    (item_type = 'recipe' and recipe_id is not null and ingredient_name is null) or
    (item_type = 'ingredient' and ingredient_name is not null and recipe_id is null)
  )
);

comment on table public.food_favorites is 'Elementos favoritos guardados a nivel de entorno (recetas o ingredientes directos)';

-- 3.5. Menús semanales guardados en la biblioteca del entorno
create table if not exists public.saved_weekly_menus (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  name text not null,
  description text null,
  created_at timestamp with time zone default now() not null
);

comment on table public.saved_weekly_menus is 'Plantillas de menús semanales guardadas en la biblioteca del entorno';

-- 3.6. Ranuras (slots) de menús semanales guardados
create table if not exists public.saved_weekly_menu_slots (
  id uuid primary key default gen_random_uuid(),
  saved_menu_id uuid not null references public.saved_weekly_menus(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 1 and 7), -- 1 = Lunes, 7 = Domingo
  meal_type text not null check (meal_type in ('breakfast', 'mid_morning', 'lunch', 'snack', 'dinner')),
  item_type text not null check (item_type in ('recipe', 'single_ingredient')),
  recipe_id uuid null references public.recipes(id) on delete cascade,
  custom_name text null,
  constraint chk_saved_slot_target check (
    (item_type = 'recipe' and recipe_id is not null) or
    (item_type = 'single_ingredient' and custom_name is not null)
  )
);

comment on table public.saved_weekly_menu_slots is 'Comidas configuradas por día de la semana para un menú guardado';

-- 3.7. Ranuras del calendario semanal activo
create table if not exists public.active_calendar_slots (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  date date not null,
  meal_type text not null check (meal_type in ('breakfast', 'mid_morning', 'lunch', 'snack', 'dinner')),
  item_type text not null check (item_type in ('recipe', 'single_ingredient')),
  recipe_id uuid null references public.recipes(id) on delete cascade,
  custom_name text null,
  constraint chk_calendar_slot_target check (
    (item_type = 'recipe' and recipe_id is not null) or
    (item_type = 'single_ingredient' and custom_name is not null)
  )
);

comment on table public.active_calendar_slots is 'Planificación de comidas activas por fecha calendario para el entorno';

-- 3.8. Ítems de la lista de la compra colaborativa
create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  name text not null,
  occurrences_count integer not null default 1 check (occurrences_count >= 1),
  category_id uuid null references public.food_categories(id) on delete set null,
  is_checked boolean not null default false,
  is_manual boolean not null default false,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

comment on table public.shopping_list_items is 'Lista de la compra colaborativa generada automáticamente o manualmente';

-- 4. TRIGGERS DE NORMALIZACIÓN Y ACTUALIZACIÓN
-- ------------------------------------------------------------------------------

-- 4.1. Normalizar ingredientes a minúsculas y trim de espacios
create or replace function public.normalize_recipe_ingredient_name()
returns trigger as $$
begin
  new.name = lower(trim(new.name));
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_normalize_recipe_ingredient on public.recipe_ingredients;
create trigger trg_normalize_recipe_ingredient
  before insert or update on public.recipe_ingredients
  for each row
  execute function public.normalize_recipe_ingredient_name();

-- 4.2. Normalizar favoritos de ingredientes
create or replace function public.normalize_food_favorite_name()
returns trigger as $$
begin
  if new.ingredient_name is not null then
    new.ingredient_name = lower(trim(new.ingredient_name));
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_normalize_food_favorite on public.food_favorites;
create trigger trg_normalize_food_favorite
  before insert or update on public.food_favorites
  for each row
  execute function public.normalize_food_favorite_name();

-- 4.3. Actualizar timestamp en shopping_list_items
create or replace function public.handle_shopping_list_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_shopping_list_items_updated_at on public.shopping_list_items;
create trigger trg_shopping_list_items_updated_at
  before update on public.shopping_list_items
  for each row
  execute function public.handle_shopping_list_updated_at();

-- 5. ÍNDICES DE RENDIMIENTO Y BÚSQUEDA EFICIENTE (B-TREE & TRIGRAM GIN)
-- ------------------------------------------------------------------------------

-- 5.1. Búsqueda por texto con ILIKE acelerada mediante pg_trgm (GIN)
create index if not exists idx_recipes_title_trgm
  on public.recipes using gin (title gin_trgm_ops);

create index if not exists idx_recipe_ingredients_name_trgm
  on public.recipe_ingredients using gin (name gin_trgm_ops);

create index if not exists idx_shopping_list_items_name_trgm
  on public.shopping_list_items using gin (name gin_trgm_ops);

-- 5.2. Claves foráneas y filtros de recetas
create index if not exists idx_recipes_environment_id
  on public.recipes (environment_id);

create index if not exists idx_recipes_is_global
  on public.recipes (is_global);

create index if not exists idx_recipes_cuisine_country
  on public.recipes (cuisine_type, country);

-- 5.3. Ingredientes
create index if not exists idx_recipe_ingredients_recipe_id
  on public.recipe_ingredients (recipe_id);

create index if not exists idx_recipe_ingredients_category_id
  on public.recipe_ingredients (category_id);

-- 5.4. Favoritos (índices únicos condicionales para evitar duplicados en el mismo entorno)
create index if not exists idx_food_favorites_env
  on public.food_favorites (environment_id);

create unique index if not exists idx_unique_food_fav_recipe
  on public.food_favorites (environment_id, recipe_id)
  where item_type = 'recipe';

create unique index if not exists idx_unique_food_fav_ingredient
  on public.food_favorites (environment_id, ingredient_name)
  where item_type = 'ingredient';

-- 5.5. Menús guardados y ranuras
create index if not exists idx_saved_weekly_menus_env
  on public.saved_weekly_menus (environment_id);

create index if not exists idx_saved_weekly_menu_slots_menu
  on public.saved_weekly_menu_slots (saved_menu_id);

create index if not exists idx_saved_weekly_menu_slots_day_meal
  on public.saved_weekly_menu_slots (day_of_week, meal_type);

-- 5.6. Calendario semanal activo
create index if not exists idx_active_cal_slots_env_date
  on public.active_calendar_slots (environment_id, date);

create index if not exists idx_active_cal_slots_date_meal
  on public.active_calendar_slots (date, meal_type);

-- 5.7. Lista de la compra
create index if not exists idx_shopping_list_items_env_checked
  on public.shopping_list_items (environment_id, is_checked);

create index if not exists idx_shopping_list_items_category
  on public.shopping_list_items (category_id);

-- 6. POLÍTICAS DE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
alter table public.food_categories enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.food_favorites enable row level security;
alter table public.saved_weekly_menus enable row level security;
alter table public.saved_weekly_menu_slots enable row level security;
alter table public.active_calendar_slots enable row level security;
alter table public.shopping_list_items enable row level security;

-- 6.1. RLS: food_categories (Lectura para usuarios autenticados)
drop policy if exists "Usuarios autenticados pueden ver categorias de alimentos" on public.food_categories;
create policy "Usuarios autenticados pueden ver categorias de alimentos"
  on public.food_categories for select
  to authenticated
  using (true);

-- 6.2. RLS: recipes
-- Recetas globales son visibles para todos; recetas caseras solo para miembros del entorno
drop policy if exists "Lectura de recetas globales o del entorno propio" on public.recipes;
create policy "Lectura de recetas globales o del entorno propio"
  on public.recipes for select
  to authenticated
  using (
    (is_global = true and environment_id is null)
    or (environment_id is not null and public.is_environment_member(environment_id))
  );

drop policy if exists "Miembros del entorno pueden crear recetas caseras" on public.recipes;
create policy "Miembros del entorno pueden crear recetas caseras"
  on public.recipes for insert
  to authenticated
  with check (
    environment_id is not null
    and is_global = false
    and public.is_environment_member(environment_id)
  );

drop policy if exists "Miembros del entorno pueden editar sus recetas caseras" on public.recipes;
create policy "Miembros del entorno pueden editar sus recetas caseras"
  on public.recipes for update
  to authenticated
  using (
    environment_id is not null
    and is_global = false
    and public.is_environment_member(environment_id)
  )
  with check (
    environment_id is not null
    and is_global = false
    and public.is_environment_member(environment_id)
  );

drop policy if exists "Miembros del entorno pueden eliminar sus recetas caseras" on public.recipes;
create policy "Miembros del entorno pueden eliminar sus recetas caseras"
  on public.recipes for delete
  to authenticated
  using (
    environment_id is not null
    and is_global = false
    and public.is_environment_member(environment_id)
  );

-- 6.3. RLS: recipe_ingredients
-- Los ingredientes son visibles si la receta asociada es visible
drop policy if exists "Lectura de ingredientes de recetas visibles" on public.recipe_ingredients;
create policy "Lectura de ingredientes de recetas visibles"
  on public.recipe_ingredients for select
  to authenticated
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and (
          (r.is_global = true and r.environment_id is null)
          or (r.environment_id is not null and public.is_environment_member(r.environment_id))
        )
    )
  );

drop policy if exists "Insercion de ingredientes en recetas caseras del entorno" on public.recipe_ingredients;
create policy "Insercion de ingredientes en recetas caseras del entorno"
  on public.recipe_ingredients for insert
  to authenticated
  with check (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and r.environment_id is not null
        and r.is_global = false
        and public.is_environment_member(r.environment_id)
    )
  );

drop policy if exists "Modificacion de ingredientes en recetas caseras del entorno" on public.recipe_ingredients;
create policy "Modificacion de ingredientes en recetas caseras del entorno"
  on public.recipe_ingredients for update
  to authenticated
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and r.environment_id is not null
        and r.is_global = false
        and public.is_environment_member(r.environment_id)
    )
  )
  with check (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and r.environment_id is not null
        and r.is_global = false
        and public.is_environment_member(r.environment_id)
    )
  );

drop policy if exists "Eliminacion de ingredientes en recetas caseras del entorno" on public.recipe_ingredients;
create policy "Eliminacion de ingredientes en recetas caseras del entorno"
  on public.recipe_ingredients for delete
  to authenticated
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and r.environment_id is not null
        and r.is_global = false
        and public.is_environment_member(r.environment_id)
    )
  );

-- 6.4. RLS: food_favorites
drop policy if exists "Miembros del entorno pueden ver favoritos" on public.food_favorites;
create policy "Miembros del entorno pueden ver favoritos"
  on public.food_favorites for select
  to authenticated
  using (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden agregar favoritos" on public.food_favorites;
create policy "Miembros del entorno pueden agregar favoritos"
  on public.food_favorites for insert
  to authenticated
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden modificar favoritos" on public.food_favorites;
create policy "Miembros del entorno pueden modificar favoritos"
  on public.food_favorites for update
  to authenticated
  using (public.is_environment_member(environment_id))
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden eliminar favoritos" on public.food_favorites;
create policy "Miembros del entorno pueden eliminar favoritos"
  on public.food_favorites for delete
  to authenticated
  using (public.is_environment_member(environment_id));

-- 6.5. RLS: saved_weekly_menus
drop policy if exists "Miembros del entorno pueden ver menus guardados" on public.saved_weekly_menus;
create policy "Miembros del entorno pueden ver menus guardados"
  on public.saved_weekly_menus for select
  to authenticated
  using (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden crear menus guardados" on public.saved_weekly_menus;
create policy "Miembros del entorno pueden crear menus guardados"
  on public.saved_weekly_menus for insert
  to authenticated
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden actualizar menus guardados" on public.saved_weekly_menus;
create policy "Miembros del entorno pueden actualizar menus guardados"
  on public.saved_weekly_menus for update
  to authenticated
  using (public.is_environment_member(environment_id))
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden borrar menus guardados" on public.saved_weekly_menus;
create policy "Miembros del entorno pueden borrar menus guardados"
  on public.saved_weekly_menus for delete
  to authenticated
  using (public.is_environment_member(environment_id));

-- 6.6. RLS: saved_weekly_menu_slots
drop policy if exists "Miembros del entorno pueden ver slots de menus guardados" on public.saved_weekly_menu_slots;
create policy "Miembros del entorno pueden ver slots de menus guardados"
  on public.saved_weekly_menu_slots for select
  to authenticated
  using (
    exists (
      select 1 from public.saved_weekly_menus m
      where m.id = saved_weekly_menu_slots.saved_menu_id
        and public.is_environment_member(m.environment_id)
    )
  );

drop policy if exists "Miembros del entorno pueden insertar slots en menus guardados" on public.saved_weekly_menu_slots;
create policy "Miembros del entorno pueden insertar slots en menus guardados"
  on public.saved_weekly_menu_slots for insert
  to authenticated
  with check (
    exists (
      select 1 from public.saved_weekly_menus m
      where m.id = saved_weekly_menu_slots.saved_menu_id
        and public.is_environment_member(m.environment_id)
    )
  );

drop policy if exists "Miembros del entorno pueden actualizar slots en menus guardados" on public.saved_weekly_menu_slots;
create policy "Miembros del entorno pueden actualizar slots en menus guardados"
  on public.saved_weekly_menu_slots for update
  to authenticated
  using (
    exists (
      select 1 from public.saved_weekly_menus m
      where m.id = saved_weekly_menu_slots.saved_menu_id
        and public.is_environment_member(m.environment_id)
    )
  )
  with check (
    exists (
      select 1 from public.saved_weekly_menus m
      where m.id = saved_weekly_menu_slots.saved_menu_id
        and public.is_environment_member(m.environment_id)
    )
  );

drop policy if exists "Miembros del entorno pueden borrar slots en menus guardados" on public.saved_weekly_menu_slots;
create policy "Miembros del entorno pueden borrar slots en menus guardados"
  on public.saved_weekly_menu_slots for delete
  to authenticated
  using (
    exists (
      select 1 from public.saved_weekly_menus m
      where m.id = saved_weekly_menu_slots.saved_menu_id
        and public.is_environment_member(m.environment_id)
    )
  );

-- 6.7. RLS: active_calendar_slots
drop policy if exists "Miembros del entorno pueden ver el calendario activo" on public.active_calendar_slots;
create policy "Miembros del entorno pueden ver el calendario activo"
  on public.active_calendar_slots for select
  to authenticated
  using (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden agregar al calendario activo" on public.active_calendar_slots;
create policy "Miembros del entorno pueden agregar al calendario activo"
  on public.active_calendar_slots for insert
  to authenticated
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden actualizar el calendario activo" on public.active_calendar_slots;
create policy "Miembros del entorno pueden actualizar el calendario activo"
  on public.active_calendar_slots for update
  to authenticated
  using (public.is_environment_member(environment_id))
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden eliminar del calendario activo" on public.active_calendar_slots;
create policy "Miembros del entorno pueden eliminar del calendario activo"
  on public.active_calendar_slots for delete
  to authenticated
  using (public.is_environment_member(environment_id));

-- 6.8. RLS: shopping_list_items
drop policy if exists "Miembros del entorno pueden ver lista de la compra" on public.shopping_list_items;
create policy "Miembros del entorno pueden ver lista de la compra"
  on public.shopping_list_items for select
  to authenticated
  using (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden agregar a lista de la compra" on public.shopping_list_items;
create policy "Miembros del entorno pueden agregar a lista de la compra"
  on public.shopping_list_items for insert
  to authenticated
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden actualizar items de lista de compra" on public.shopping_list_items;
create policy "Miembros del entorno pueden actualizar items de lista de compra"
  on public.shopping_list_items for update
  to authenticated
  using (public.is_environment_member(environment_id))
  with check (public.is_environment_member(environment_id));

drop policy if exists "Miembros del entorno pueden eliminar items de lista de compra" on public.shopping_list_items;
create policy "Miembros del entorno pueden eliminar items de lista de compra"
  on public.shopping_list_items for delete
  to authenticated
  using (public.is_environment_member(environment_id));

-- 7. CARGA DE CATEGORÍAS MAESTRAS DETERMINISTAS
-- ------------------------------------------------------------------------------
insert into public.food_categories (id, name, icon_slug)
values
  ('00000000-0000-0000-0000-000000000001', 'Lácteos y Derivados', 'dairy'),
  ('00000000-0000-0000-0000-000000000002', 'Frutas', 'fruit'),
  ('00000000-0000-0000-0000-000000000003', 'Verduras y Hortalizas', 'vegetable'),
  ('00000000-0000-0000-0000-000000000004', 'Carnes y Aves', 'meat'),
  ('00000000-0000-0000-0000-000000000005', 'Pescados y Mariscos', 'fish'),
  ('00000000-0000-0000-0000-000000000006', 'Cereales, Legumbres y Pastas', 'grain'),
  ('00000000-0000-0000-0000-000000000007', 'Panadería y Masas', 'bakery'),
  ('00000000-0000-0000-0000-000000000008', 'Snacks y Dulces', 'snack'),
  ('00000000-0000-0000-0000-000000000009', 'Limpieza y Hogar', 'cleaning')
on conflict (icon_slug) do update set
  name = excluded.name;
