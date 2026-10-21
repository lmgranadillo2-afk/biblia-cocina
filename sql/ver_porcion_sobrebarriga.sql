-- Solo lectura: dónde está la receta "PORCION SOBREBARRIGA" y qué la usa. No cambia nada.
with receta as (
  select r.id, r.code, r.name, r.yield_qty, r.yield_unit, r.porcion_gr, l.name as punto, a.name as area, r.area_id
  from public.recipes r
  join public.locations l on l.id = r.location_id
  join public.areas a on a.id = r.area_id
  where r.name ilike '%sobrebarriga%' or r.name ilike '%molcajete%'
)
select 'receta' as tipo, punto, area, code, name as nombre, yield_qty || ' ' || yield_unit as rinde, porcion_gr::text as detalle
from receta
union all
-- Otras recetas que la usan como ingrediente (subreceta)
select 'la usa la receta', l.name, a.name, r.code, r.name, null, ing->>'name'
from public.recipes r
join public.locations l on l.id = r.location_id
join public.areas a on a.id = r.area_id
cross join lateral jsonb_array_elements(r.ingredients) ing
where (ing->>'name') ilike '%sobrebarriga%' or (ing->>'code') in (select code from receta)
union all
select 'producciones registradas', null, null, recipe_code, recipe_name, null, count(*)::text
from public.productions where recipe_name ilike '%sobrebarriga%' group by recipe_code, recipe_name
union all
select 'en cronograma', null, null, recipe_code, recipe_name, null, count(*)::text
from public.schedule_items where recipe_name ilike '%sobrebarriga%' group by recipe_code, recipe_name
order by 1, 2;
