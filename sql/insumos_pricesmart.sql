-- Insumos de PriceSmart con su código de producto (26 oct 2026). No borra datos; se puede correr más de una vez.
-- * Agrega group_ingredient_proveedores.codigo_proveedor: el código del producto en ese proveedor (sale en el mensaje del pedido).
-- * Proveedor PriceSmart (lo crea si no existe) activo en Cocina de Dos Santos Medellín, Dos Santos Cali y Rúnico.
-- * Cada insumo: si ya existe UNO con ese nombre en el catálogo se usa ese; si no existe se crea; si hay varios parecidos
--   no se toca y sale como "revisar" en el resultado. Se activa en los tres puntos y se vincula a PriceSmart con su código.
alter table public.group_ingredient_proveedores add column if not exists codigo_proveedor text;

drop table if exists tmp_ps;
create temporary table tmp_ps (orden int, nombre text, patron text, categoria text, codigo text, resultado text, ingredient_id uuid);
insert into tmp_ps (orden, nombre, patron, categoria, codigo) values
  (1, 'QUESO MANCHEGO', '%manchego%', 'LAC', '176353'),
  (2, 'QUESO PARMESANO', '%parmes%', 'LAC', '176353'),
  (3, 'ACEITE DE OLIVA', '%aceite%oliva%', 'ABA', '388043'),
  (4, 'QUESO CHEDDAR LATA', '%cheddar%lata%', 'LAC', '25440'),
  (5, 'QUESO CREMA PHILADELPHIA', '%philadelphia%', 'LAC', '4681506'),
  (6, 'QUESO MASCARPONE', '%mascarpone%', 'LAC', null);

do $$
declare v_prov uuid; r record; v_n int; v_id uuid; v_locs uuid[];
begin
  select id into v_prov from public.proveedores where lower(replace(nombre, ' ', '')) in ('pricesmart', 'priscemart', 'pricemart') limit 1;
  if v_prov is null then insert into public.proveedores (nombre) values ('PriceSmart') returning id into v_prov; end if;

  select array_agg(l.id) into v_locs from public.locations l
  where l.slug in ('dos-santos', 'dos-santos-cali-mtg0p7fs') or translate(lower(l.name), 'ú', 'u') like '%runico%';
  if coalesce(array_length(v_locs, 1), 0) <> 3 then raise exception 'Encontré % puntos, esperaba 3: no cambié nada', coalesce(array_length(v_locs, 1), 0); end if;

  -- PriceSmart activo en las tres cocinas
  insert into public.area_proveedores (area_id, proveedor_id)
  select a.id, v_prov from public.areas a where a.location_id = any(v_locs) and upper(trim(a.name)) like 'COCINA%'
    and not exists (select 1 from public.area_proveedores x where x.area_id = a.id and x.proveedor_id = v_prov);

  for r in select * from tmp_ps order by orden loop
    select count(*) into v_n from public.group_ingredients where name ilike r.patron;
    if v_n > 1 then
      update tmp_ps set resultado = 'revisar: hay ' || v_n || ' parecidos' where orden = r.orden;
      continue;
    elsif v_n = 1 then
      select id into v_id from public.group_ingredients where name ilike r.patron;
      update tmp_ps set resultado = 'ya existía' where orden = r.orden;
    else
      insert into public.group_ingredients (code, name, categoria)
      values (r.categoria || '-' || upper(substr(md5(random()::text || r.nombre), 1, 6)), r.nombre, r.categoria)
      returning id into v_id;
      update tmp_ps set resultado = 'creado' where orden = r.orden;
    end if;
    update tmp_ps set ingredient_id = v_id where orden = r.orden;

    insert into public.location_ingredient_activation (location_id, ingredient_id, active)
    select l, v_id, true from unnest(v_locs) l
    where not exists (select 1 from public.location_ingredient_activation x where x.location_id = l and x.ingredient_id = v_id);
    update public.location_ingredient_activation set active = true where ingredient_id = v_id and location_id = any(v_locs);

    if not exists (select 1 from public.group_ingredient_proveedores x where x.ingredient_id = v_id and x.proveedor_id = v_prov) then
      insert into public.group_ingredient_proveedores (ingredient_id, proveedor_id, codigo_proveedor) values (v_id, v_prov, r.codigo);
    else
      update public.group_ingredient_proveedores set codigo_proveedor = coalesce(r.codigo, codigo_proveedor)
      where ingredient_id = v_id and proveedor_id = v_prov;
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar los 6 insumos con "creado" o "ya existía" (si alguno dice "revisar", avísale a Claude)
select t.nombre as pedido, t.resultado, g.code, g.name as en_el_catalogo, t.codigo as codigo_pricesmart
from tmp_ps t left join public.group_ingredients g on g.id = t.ingredient_id order by t.orden;
