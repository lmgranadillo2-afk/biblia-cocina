-- Eventos: versión del cálculo de la cotización e IVA sobre extras, sin cambiar las ya hechas.
--   version_calculo 1 = como antes: "Servicio" calculado sobre el total con ICO (eventos existentes).
--   version_calculo 2 = legal (Ley 1935 de 2018): "Propina voluntaria sugerida", máx. 10 %,
--                       sobre el valor sin impuestos, con la nota de voluntariedad (eventos nuevos).
--   iva_extras_pct    = IVA sobre personal y otros ítems (menaje, DJ, shows...). La carta lleva ICO, no IVA.
--                       Eventos existentes: 0. Eventos nuevos: 19 (lo pone la app).
-- Carta: precio_manual = el precio se cambió en la app y la sincronización con Toteat no lo toca.
-- Solo agrega columnas. Se puede correr más de una vez.
alter table public.costeo_eventos
  add column if not exists version_calculo integer not null default 1,
  add column if not exists iva_extras_pct numeric not null default 0;

alter table public.carta_items
  add column if not exists precio_manual boolean not null default false;

notify pgrst, 'reload schema';
