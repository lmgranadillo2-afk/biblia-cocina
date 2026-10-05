-- PORCION CHATA X 100 GR — solo Dos Santos Cali (área Cocina).
-- 1 kg de CHATA INS (PRO011) cruda rinde 700 g limpios = 7 porciones de 100 g.
-- Código: el siguiente SUBC libre. No se duplica si ya existe. Se puede correr más de una vez.
do $$
declare
  v_loc uuid;
  v_area uuid;
  v_code text;
begin
  select id into v_loc from public.locations where slug = 'dos-santos-cali-mtg0p7fs';
  select a.id into v_area from public.areas a
    where a.location_id = v_loc and upper(a.name) like 'COCINA%'
    order by a.name limit 1;
  if v_area is null then raise exception 'No encontré el área Cocina de Dos Santos Cali'; end if;

  if exists (select 1 from public.recipes where area_id = v_area and upper(trim(name)) = 'PORCION CHATA X 100 GR') then
    raise notice 'Ya existe, no se crea de nuevo';
    return;
  end if;

  select 'SUBC' || lpad((coalesce(max(substring(code from 5)::int), 0) + 1)::text, 3, '0') into v_code
    from public.recipes where code ~ '^SUBC[0-9]+$';

  insert into public.recipes (code, name, yield_qty, yield_unit, ingredients, location_id, area_id, porcion_gr)
  values (v_code, 'PORCION CHATA X 100 GR', 7, 'UNIDAD',
    '[{"qty":"1000","code":"PRO011","name":"CHATA INS","unit":"GR"}]'::jsonb,
    v_loc, v_area, 100);
end $$;

-- Debe mostrar la receta nueva en Dos Santos Cali
select l.name as punto, a.name as area, r.code, r.name, r.yield_qty, r.yield_unit, r.porcion_gr, r.ingredients
from public.recipes r
join public.locations l on l.id = r.location_id
join public.areas a on a.id = r.area_id
where upper(trim(r.name)) = 'PORCION CHATA X 100 GR';
