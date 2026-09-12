-- ==============================================================================
-- MIGRACIÓN: 20260912_leisure_module.sql
-- Módulo de Ocio (Leisure) para MarthApp (Cine, Series, Libros y Videojuegos)
-- ==============================================================================

-- 1. TIPOS Y ENUMS
-- ------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'leisure_media_type') then
    create type public.leisure_media_type as enum ('movie', 'tv', 'book', 'game');
  end if;

  if not exists (select 1 from pg_type where typname = 'leisure_item_status') then
    create type public.leisure_item_status as enum ('watched', 'to_watch', 'favorite', 'watching');
  end if;
end;
$$;

-- 2. TABLAS E INTEGRIDAD
-- ------------------------------------------------------------------------------

-- 2.1. Tabla: leisure_user_items (Progreso Personal y Calificaciones Privadas)
create table if not exists public.leisure_user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_id text not null,
  media_type public.leisure_media_type not null,
  status public.leisure_item_status,
  rating numeric(3, 1) check (rating >= 1.0 and rating <= 10.0),
  notes text,
  disliked_until timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint uq_leisure_user_item unique (user_id, media_id, media_type)
);

comment on table public.leisure_user_items is 'Progreso personal, calificaciones privadas y descarte de feed para usuarios';

-- 2.2. Tabla: leisure_shared_lists (Listas Temáticas del Entorno)
create table if not exists public.leisure_shared_lists (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  title text not null,
  description text,
  created_at timestamp with time zone default now() not null
);

comment on table public.leisure_shared_lists is 'Listas temáticas colaborativas vinculadas a un entorno de trabajo';

-- 2.3. Tabla: leisure_shared_list_items (Ítems en Listas Compartidas)
create table if not exists public.leisure_shared_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.leisure_shared_lists(id) on delete cascade,
  media_id text not null,
  media_type public.leisure_media_type not null,
  title text not null,
  poster_url text,
  added_by uuid not null references auth.users(id),
  created_at timestamp with time zone default now() not null,
  constraint uq_leisure_shared_item unique (list_id, media_id, media_type)
);

comment on table public.leisure_shared_list_items is 'Elementos multimedia añadidos a listas compartidas de un entorno';

-- 2.4. Tabla: leisure_environment_matches (Coincidencias de Watch Party)
create table if not exists public.leisure_environment_matches (
  id uuid primary key default gen_random_uuid(),
  environment_id uuid not null references public.environments(id) on delete cascade,
  media_id text not null,
  media_type public.leisure_media_type not null,
  title text not null,
  matched_user_ids uuid[] not null default '{}',
  created_at timestamp with time zone default now() not null,
  constraint uq_leisure_env_match unique (environment_id, media_id, media_type)
);

comment on table public.leisure_environment_matches is 'Coincidencias mutuas de likes entre miembros de un mismo entorno (Watch Party)';

-- 2.5. Tabla: leisure_media_cache (Caché de Metadatos Externos)
create table if not exists public.leisure_media_cache (
  media_id text not null,
  media_type public.leisure_media_type not null,
  payload jsonb not null,
  cached_at timestamp with time zone default now() not null,
  primary key (media_id, media_type)
);

comment on table public.leisure_media_cache is 'Caché persistente de respuestas pesadas de APIs externas (TMDB, Open Library, IGDB)';

-- 3. ÍNDICES DE RENDIMIENTO OBLIGATORIOS
-- ------------------------------------------------------------------------------
create index if not exists idx_leisure_user_items_user_status
  on public.leisure_user_items (user_id, status);

create index if not exists idx_leisure_shared_lists_env
  on public.leisure_shared_lists (environment_id);

create index if not exists idx_leisure_shared_list_items_list
  on public.leisure_shared_list_items (list_id);

create index if not exists idx_leisure_media_cache_date
  on public.leisure_media_cache (cached_at);

create index if not exists idx_leisure_env_matches_env
  on public.leisure_environment_matches (environment_id);

-- Trigger de actualización para leisure_user_items.updated_at
create or replace function public.handle_leisure_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_leisure_user_items_updated_at on public.leisure_user_items;
create trigger trg_leisure_user_items_updated_at
  before update on public.leisure_user_items
  for each row
  execute function public.handle_leisure_updated_at();

-- 4. POLÍTICAS ROW LEVEL SECURITY (RLS) RIGUROSAS
-- ------------------------------------------------------------------------------
alter table public.leisure_user_items enable row level security;
alter table public.leisure_shared_lists enable row level security;
alter table public.leisure_shared_list_items enable row level security;
alter table public.leisure_environment_matches enable row level security;
alter table public.leisure_media_cache enable row level security;

-- 4.1. RLS: leisure_user_items (Aislamiento absoluto por usuario)
drop policy if exists "Los usuarios pueden ver su propio progreso de ocio" on public.leisure_user_items;
create policy "Los usuarios pueden ver su propio progreso de ocio"
  on public.leisure_user_items for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Los usuarios pueden registrar su propio progreso de ocio" on public.leisure_user_items;
create policy "Los usuarios pueden registrar su propio progreso de ocio"
  on public.leisure_user_items for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Los usuarios pueden actualizar su propio progreso de ocio" on public.leisure_user_items;
create policy "Los usuarios pueden actualizar su propio progreso de ocio"
  on public.leisure_user_items for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Los usuarios pueden eliminar su propio progreso de ocio" on public.leisure_user_items;
create policy "Los usuarios pueden eliminar su propio progreso de ocio"
  on public.leisure_user_items for delete
  to authenticated
  using (auth.uid() = user_id);

-- 4.2. RLS: leisure_shared_lists (Membresía activa en el entorno)
drop policy if exists "Miembros del entorno pueden ver sus listas compartidas" on public.leisure_shared_lists;
create policy "Miembros del entorno pueden ver sus listas compartidas"
  on public.leisure_shared_lists for select
  to authenticated
  using (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_shared_lists.environment_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros del entorno pueden crear listas compartidas" on public.leisure_shared_lists;
create policy "Miembros del entorno pueden crear listas compartidas"
  on public.leisure_shared_lists for insert
  to authenticated
  with check (
    auth.uid() = created_by and
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_shared_lists.environment_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros del entorno pueden actualizar listas compartidas" on public.leisure_shared_lists;
create policy "Miembros del entorno pueden actualizar listas compartidas"
  on public.leisure_shared_lists for update
  to authenticated
  using (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_shared_lists.environment_id
        and em.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_shared_lists.environment_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Creadores o propietarios del entorno pueden eliminar listas" on public.leisure_shared_lists;
create policy "Creadores o propietarios del entorno pueden eliminar listas"
  on public.leisure_shared_lists for delete
  to authenticated
  using (
    auth.uid() = created_by or
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_shared_lists.environment_id
        and em.user_id = auth.uid()
        and em.role = 'owner'
    )
  );

-- 4.3. RLS: leisure_shared_list_items (Validación atómica contra entorno vinculado a list_id)
drop policy if exists "Miembros del entorno pueden ver ítems de listas" on public.leisure_shared_list_items;
create policy "Miembros del entorno pueden ver ítems de listas"
  on public.leisure_shared_list_items for select
  to authenticated
  using (
    exists (
      select 1 from public.leisure_shared_lists l
      join public.environment_members em on em.environment_id = l.environment_id
      where l.id = leisure_shared_list_items.list_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros del entorno pueden añadir ítems con check atómico" on public.leisure_shared_list_items;
create policy "Miembros del entorno pueden añadir ítems con check atómico"
  on public.leisure_shared_list_items for insert
  to authenticated
  with check (
    added_by = auth.uid() and
    exists (
      select 1 from public.leisure_shared_lists l
      join public.environment_members em on em.environment_id = l.environment_id
      where l.id = leisure_shared_list_items.list_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros que añadieron o del entorno pueden eliminar ítems" on public.leisure_shared_list_items;
create policy "Miembros que añadieron o del entorno pueden eliminar ítems"
  on public.leisure_shared_list_items for delete
  to authenticated
  using (
    added_by = auth.uid() or
    exists (
      select 1 from public.leisure_shared_lists l
      join public.environment_members em on em.environment_id = l.environment_id
      where l.id = leisure_shared_list_items.list_id
        and em.user_id = auth.uid()
    )
  );

-- 4.4. RLS: leisure_environment_matches
drop policy if exists "Miembros del entorno pueden ver matches de watch party" on public.leisure_environment_matches;
create policy "Miembros del entorno pueden ver matches de watch party"
  on public.leisure_environment_matches for select
  to authenticated
  using (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_environment_matches.environment_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros del entorno pueden registrar matches de watch party" on public.leisure_environment_matches;
create policy "Miembros del entorno pueden registrar matches de watch party"
  on public.leisure_environment_matches for insert
  to authenticated
  with check (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_environment_matches.environment_id
        and em.user_id = auth.uid()
    )
  );

drop policy if exists "Miembros del entorno pueden actualizar matches de watch party" on public.leisure_environment_matches;
create policy "Miembros del entorno pueden actualizar matches de watch party"
  on public.leisure_environment_matches for update
  to authenticated
  using (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_environment_matches.environment_id
        and em.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.environment_members em
      where em.environment_id = leisure_environment_matches.environment_id
        and em.user_id = auth.uid()
    )
  );

-- 4.5. RLS: leisure_media_cache (Lectura e inserción/actualización para autenticados)
drop policy if exists "Usuarios autenticados pueden consultar el cache de medios" on public.leisure_media_cache;
create policy "Usuarios autenticados pueden consultar el cache de medios"
  on public.leisure_media_cache for select
  to authenticated
  using (true);

drop policy if exists "Usuarios autenticados pueden insertar en el cache de medios" on public.leisure_media_cache;
create policy "Usuarios autenticados pueden insertar en el cache de medios"
  on public.leisure_media_cache for insert
  to authenticated
  with check (true);

drop policy if exists "Usuarios autenticados pueden actualizar el cache de medios" on public.leisure_media_cache;
create policy "Usuarios autenticados pueden actualizar el cache de medios"
  on public.leisure_media_cache for update
  to authenticated
  using (true)
  with check (true);
