-- Porciones empacadas en producción (ej. tinga en porciones de 110 g).
--   recipes.porcion_gr: peso de la porción de esa receta (lo define un admin en el recetario).
--   productions.porciones / porcion_gr: cuántas porciones se empacaron e ingresan, y de cuánto.
-- Solo agrega columnas y fija la tinga en 110 g en Cantina Dos Santos y Dos Santos Cali. Se puede correr más de una vez.
alter table public.recipes add column if not exists porcion_gr numeric;
alter table public.productions add column if not exists porciones integer;
alter table public.productions add column if not exists porcion_gr numeric;

update public.recipes set porcion_gr = 110
where upper(trim(name)) = 'TINGA DE POLLO'
  and location_id in (select id from public.locations where slug in ('dos-santos', 'dos-santos-cali-mtg0p7fs'));

-- Debe mostrar la tinga de los dos puntos con 110
select l.name as punto, r.code, r.name, r.porcion_gr
from public.recipes r join public.locations l on l.id = r.location_id
where r.porcion_gr is not null;

notify pgrst, 'reload schema';
