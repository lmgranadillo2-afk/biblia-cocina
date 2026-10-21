-- Cambia el nombre de la receta "PORCION SOBREBARRIGA…" a "PORCION MOLCAJETE…" en Cantina Dos Santos y Dos Santos Cali.
-- Solo el nombre: código, rendimiento, porción e ingredientes quedan igual. Se conserva el resto del nombre (ej. " X 200 GR").
-- También corrige el nombre donde otras recetas la usan como ingrediente y en el cronograma de hoy en adelante.
-- El historial (producciones y bajas ya registradas) NO se toca: sigue ligado por el código.
-- No borra nada. Se puede correr más de una vez.

with puntos as (
  select id from public.locations where slug in ('dos-santos', 'dos-santos-cali-mtg0p7fs')
),
renombradas as (
  update public.recipes r
  set name = regexp_replace(r.name, 'SOBREBARRIGA', 'MOLCAJETE', 'i')
  where r.location_id in (select id from puntos)
    and r.name ~* '^\s*PORCI[OÓ]N\s+SOBREBARRIGA'
  returning r.code, r.name, r.location_id
),
en_otras as (
  update public.recipes r
  set ingredients = (
    select jsonb_agg(case when ing->>'code' in (select code from renombradas)
                          then jsonb_set(ing, '{name}', to_jsonb((select n.name from renombradas n where n.code = ing->>'code' limit 1)))
                          else ing end order by ord)
    from jsonb_array_elements(r.ingredients) with ordinality as t(ing, ord))
  where r.location_id in (select id from puntos)
    and exists (select 1 from jsonb_array_elements(r.ingredients) ing where ing->>'code' in (select code from renombradas))
  returning r.code
),
en_cronograma as (
  update public.schedule_items s
  set recipe_name = n.name
  from renombradas n
  where s.recipe_code = n.code and s.location_id = n.location_id
    and s.fecha >= (now() at time zone 'America/Bogota')::date
  returning s.id
)
select l.name as punto, n.code, n.name as nombre_nuevo,
  (select count(*) from en_otras) as recetas_que_la_usan_actualizadas,
  (select count(*) from en_cronograma) as cronograma_actualizado
from renombradas n
join public.locations l on l.id = n.location_id
order by l.name;
