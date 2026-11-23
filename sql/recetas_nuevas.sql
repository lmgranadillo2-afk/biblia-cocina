-- Recetas nuevas: fichas de recetas en desarrollo (formato de la ficha de Dos Santos) con precio por kg / l / und,
-- costo por línea, costo total y rendimiento. Solo las ven y editan los super admin (decisión de Miguel, 23 nov 2026).
-- Cada ficha es de un restaurante (su logo y su Toteat para traer precios). No aparecen en Recetario, Producción,
-- Costeo, Bajas ni Inventario hasta que se pasan al Recetario (crea la receta en el área elegida).
-- No borra datos. Se puede correr más de una vez.

create table if not exists public.recetas_nuevas (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  codigo text,
  nombre text not null default '',
  categoria text,
  rinde numeric,
  rinde_unidad text not null default 'kg',
  procedimiento text,
  -- [{ing, peso, unidad, precio, por, obs, toteat: {nombre, unidad, costo, fecha} | null, code}]
  filas jsonb not null default '[]'::jsonb,
  pasada_recipe_id uuid,
  pasada_area_id uuid,
  pasada_por text,
  pasada_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists recetas_nuevas_location_idx on public.recetas_nuevas (location_id);
alter table public.recetas_nuevas enable row level security;

drop policy if exists recetas_nuevas_super_admin on public.recetas_nuevas;
create policy recetas_nuevas_super_admin on public.recetas_nuevas for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

create or replace function public.recetas_nuevas_tocar()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists recetas_nuevas_updated on public.recetas_nuevas;
create trigger recetas_nuevas_updated before update on public.recetas_nuevas
  for each row execute function public.recetas_nuevas_tocar();

notify pgrst, 'reload schema';

-- Revisión: debe salir recetas_nuevas.
select tablename from pg_tables where schemaname = 'public' and tablename = 'recetas_nuevas';
