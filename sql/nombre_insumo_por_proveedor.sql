-- Nombre con que cada proveedor conoce un insumo (para el mensaje del pedido). Ej.: en Zumeats, Strip loin = New York.
-- No borra datos; se puede correr más de una vez. Vacío = se usa el nombre normal del insumo.
alter table public.group_ingredient_proveedores add column if not exists nombre_proveedor text;

-- Strip loin → "New York" en Zumeats (vincula el insumo al proveedor si todavía no lo estaba)
do $$
declare v_prov uuid; v_n int;
begin
  select id into v_prov from public.proveedores where lower(trim(nombre)) = 'zumeats' limit 1;
  if v_prov is null then raise exception 'No encontré el proveedor Zumeats'; end if;
  select count(*) into v_n from public.group_ingredients where name ilike '%strip%loin%';
  if v_n = 0 then raise exception 'No encontré ningún insumo que se llame Strip loin'; end if;

  insert into public.group_ingredient_proveedores (ingredient_id, proveedor_id)
  select g.id, v_prov from public.group_ingredients g
  where g.name ilike '%strip%loin%'
    and not exists (select 1 from public.group_ingredient_proveedores x where x.ingredient_id = g.id and x.proveedor_id = v_prov);

  update public.group_ingredient_proveedores x set nombre_proveedor = 'New York'
  from public.group_ingredients g
  where g.id = x.ingredient_id and x.proveedor_id = v_prov and g.name ilike '%strip%loin%';
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar el (o los) Strip loin con "New York" para Zumeats
select g.code, g.name, p.nombre as proveedor, x.nombre_proveedor
from public.group_ingredient_proveedores x
join public.group_ingredients g on g.id = x.ingredient_id
join public.proveedores p on p.id = x.proveedor_id
where x.nombre_proveedor is not null;
