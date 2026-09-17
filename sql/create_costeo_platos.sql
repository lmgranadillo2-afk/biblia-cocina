-- Tabla nueva y separada para el módulo Costeo — "armar plato" con insumos,
-- subrecetas y otros costos. NO toca recipes/productions: los platos acá
-- solo referencian códigos de insumos/subrecetas para calcular el costo,
-- nunca modifican el recetario ni las producciones ya cargadas.

create table if not exists public.costeo_platos (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  area_id uuid not null references public.areas(id),
  nombre text not null,
  items jsonb not null default '[]'::jsonb,
  impuesto_pct numeric not null default 0,
  empaque_fijo numeric not null default 0,
  mano_obra_fijo numeric not null default 0,
  porciones numeric not null default 1,
  precio_venta numeric,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.costeo_platos enable row level security;

create policy "costeo_platos_select" on public.costeo_platos
  for select using (public.has_area_access(area_id));

create policy "costeo_platos_insert" on public.costeo_platos
  for insert with check (public.has_area_access(area_id));

create policy "costeo_platos_update" on public.costeo_platos
  for update using (public.has_area_access(area_id));

create policy "costeo_platos_delete" on public.costeo_platos
  for delete using (public.has_area_access(area_id));
