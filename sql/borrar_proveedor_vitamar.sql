-- Borrar el proveedor VITAMAR (pedido por Miguel, 26 oct 2026).
-- Si ya tiene pedidos, NO se borra (dañaría el historial): se desactiva en todas las áreas y deja de salir en Pedidos.
-- Si no tiene pedidos: se borran sus vínculos con áreas e insumos y el proveedor.
-- Todo o nada: si algo falla, no cambia nada.
do $$
declare v_id uuid; v_n int; v_pedidos int;
begin
  select count(*) into v_n from public.proveedores where upper(trim(nombre)) like '%VITAMAR%';
  if v_n = 0 then raise exception 'No hay ningún proveedor con el nombre VITAMAR'; end if;
  if v_n > 1 then raise exception 'Hay % proveedores con VITAMAR en el nombre: revisa cuál borrar antes de seguir', v_n; end if;
  select id into v_id from public.proveedores where upper(trim(nombre)) like '%VITAMAR%';

  select count(*) into v_pedidos from public.orders where proveedor_id = v_id;
  delete from public.area_proveedores where proveedor_id = v_id;

  if v_pedidos > 0 then
    raise notice 'VITAMAR tiene % pedidos: quedó desactivado en todas las áreas, pero no se borró para no dañar el historial', v_pedidos;
  else
    delete from public.group_ingredient_proveedores where proveedor_id = v_id;
    delete from public.proveedores where id = v_id;
    raise notice 'VITAMAR borrado';
  end if;
end $$;

-- Debe mostrar: 0 si se borró; 1 (sin áreas activas) si tenía pedidos
select p.nombre, (select count(*) from public.area_proveedores ap where ap.proveedor_id = p.id) as areas_activas,
       (select count(*) from public.orders o where o.proveedor_id = p.id) as pedidos
from public.proveedores p where upper(trim(p.nombre)) like '%VITAMAR%';
