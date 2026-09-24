-- Eventos: menú por tiempos (Entrada, Fuerte, Postre...).
-- tiempos: [{nombre, cantidad, opciones:[{carta_item_id, categoria, nombre, precio, costo}]}]
--   Cada tiempo se cobra una vez: precio de la opción más cara × cantidad
--   (cantidad null = número de invitados). Costo interno = costo más alto × cantidad.
-- Solo agrega una columna; los ítems de carta ya cargados en eventos siguen en "items".
alter table public.costeo_eventos
  add column if not exists tiempos jsonb not null default '[]'::jsonb;
