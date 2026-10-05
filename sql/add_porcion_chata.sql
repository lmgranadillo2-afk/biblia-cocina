-- PORCION CHATA X 100 GR — Cantina Dos Santos y Dos Santos Cali (área Cocina), mismo código en los dos.
-- 1 kg de CHATA INS (PRO011) cruda rinde 700 g limpios = 7 porciones de 100 g.
-- Código: si ya existe en alguno de los dos puntos se reutiliza; si no, el siguiente SUBC libre.
-- No se duplica. Se puede correr más de una vez.
do $$
declare
  v_slug text;
  v_loc uuid;
  v_area uuid;
  v_code text;
begin
  select code into v_code from public.recipes where upper(trim(name)) = 'PORCION CHATA X 100 GR' limit 1;
  if v_code is null then
    select 'SUBC' || lpad((coalesce(max(substring(code from 5)::int), 0) + 1)::text, 3, '0') into v_code
      from public.recipes where code ~ '^SUBC[0-9]+$';
  end if;

  foreach v_slug in array array['dos-santos', 'dos-santos-cali-mtg0p7fs'] loop
    select id into v_loc from public.locations where slug = v_slug;
    v_area := null;
    select a.id into v_area from public.areas a
      where a.location_id = v_loc and upper(a.name) like 'COCINA%'
      order by a.name limit 1;
    if v_area is null then raise exception 'No encontré el área Cocina de %', v_slug; end if;

    if not exists (select 1 from public.recipes where area_id = v_area and upper(trim(name)) = 'PORCION CHATA X 100 GR') then
      insert into public.recipes (code, name, yield_qty, yield_unit, ingredients, location_id, area_id, porcion_gr)
      values (v_code, 'PORCION CHATA X 100 GR', 7, 'UNIDAD',
        '[{"qty":"1000","code":"PRO011","name":"CHATA INS","unit":"GR"}]'::jsonb,
        v_loc, v_area, 100);
    end if;
  end loop;
end $$;

-- Debe mostrar dos filas: Cantina Dos Santos y Dos Santos Cali, con el mismo código
select l.name as punto, a.name as area, r.code, r.name, r.yield_qty, r.yield_unit, r.porcion_gr
from public.recipes r
join public.locations l on l.id = r.location_id
join public.areas a on a.id = r.area_id
where upper(trim(r.name)) = 'PORCION CHATA X 100 GR';
