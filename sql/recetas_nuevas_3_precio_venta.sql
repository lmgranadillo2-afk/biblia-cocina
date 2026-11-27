-- Recetas nuevas, paso 3: precio de venta de los platos terminados (decisiones de Miguel, 27 nov 2026).
-- Se escribe el precio de carta (con ICO) y la ficha calcula ICO, venta sin ICO, food cost, utilidad bruta y
-- el precio sugerido según un food cost objetivo (30 % por defecto). Merma o imprevistos % se suma al costo.
-- Solo agrega columnas. No borra datos. Se puede correr más de una vez. Correr ANTES de subir la app.

alter table public.recetas_nuevas add column if not exists precio_venta numeric;
alter table public.recetas_nuevas add column if not exists ico_pct numeric not null default 8;
alter table public.recetas_nuevas add column if not exists merma_pct numeric not null default 0;
alter table public.recetas_nuevas add column if not exists foodcost_obj numeric not null default 30;

notify pgrst, 'reload schema';

-- Revisión: deben salir las 4 columnas.
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'recetas_nuevas'
  and column_name in ('precio_venta', 'ico_pct', 'merma_pct', 'foodcost_obj');
