-- Enlace de la carta con Toteat: cada ítem guarda su ID de producto en Toteat
-- y la fecha de la última sincronización. Solo agrega columnas; no modifica datos.
alter table public.carta_items
  add column if not exists toteat_id text,
  add column if not exists toteat_sync_at timestamptz;

create unique index if not exists carta_items_location_toteat_id
  on public.carta_items (location_id, toteat_id)
  where toteat_id is not null;
