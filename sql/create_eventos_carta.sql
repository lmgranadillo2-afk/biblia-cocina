-- Costeo — Eventos (paso 2)
-- Correr DESPUÉS de create_costeo_cargos.sql y ANTES de load_carta_dos_santos.sql.
-- Solo crea tablas nuevas; no toca datos existentes.

-- 1) Carta de venta por PUNTO (ítems que se pueden cotizar en un evento).
--    precio = precio de venta al cliente; costo = opcional, para ver ganancia interna.
create table if not exists public.carta_items (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  categoria text not null,
  nombre text not null,
  descripcion text,
  precio numeric not null default 0,
  costo numeric,
  activo boolean not null default true,
  orden integer not null default 0,
  created_at timestamptz not null default now(),
  unique (location_id, categoria, nombre)
);

alter table public.carta_items enable row level security;

create policy carta_items_select on public.carta_items
  for select using (public.has_location_access(location_id));

create policy carta_items_insert on public.carta_items
  for insert with check (public.is_admin() and public.has_location_access(location_id));

create policy carta_items_update on public.carta_items
  for update using (public.is_admin() and public.has_location_access(location_id));

create policy carta_items_delete on public.carta_items
  for delete using (public.is_admin() and public.has_location_access(location_id));

-- 2) Eventos por PUNTO. Las líneas se guardan como jsonb con el precio del
--    momento de la cotización (si la carta cambia de precio, el evento no cambia).
--    items:    [{carta_item_id, categoria, nombre, precio, costo, cantidad}]
--    personal: [{cargo_id, nombre, personas, horas, valor_hora}]
--    otros:    [{descripcion, cantidad, precio, costo}]   (menaje, experiencia, DJ...)
create table if not exists public.costeo_eventos (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  nombre text not null,
  cliente text,
  fecha date,
  invitados integer not null default 0,
  items jsonb not null default '[]'::jsonb,
  personal jsonb not null default '[]'::jsonb,
  margen_personal_pct numeric not null default 40,
  otros jsonb not null default '[]'::jsonb,
  descuento_tipo text not null default 'pct' check (descuento_tipo in ('pct','valor')),
  descuento_valor numeric not null default 0,
  servicio_pct numeric not null default 10,
  anticipo_pct numeric not null default 50,
  notas text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.costeo_eventos enable row level security;

create policy costeo_eventos_select on public.costeo_eventos
  for select using (public.has_location_access(location_id));

create policy costeo_eventos_insert on public.costeo_eventos
  for insert with check (public.has_location_access(location_id));

create policy costeo_eventos_update on public.costeo_eventos
  for update using (public.has_location_access(location_id));

create policy costeo_eventos_delete on public.costeo_eventos
  for delete using (public.has_location_access(location_id));
