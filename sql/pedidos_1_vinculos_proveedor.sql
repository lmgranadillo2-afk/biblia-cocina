-- Pedidos · Paso 1: vínculos insumo ↔ proveedor automáticos
-- 1) Vincula cada proveedor con los insumos que ya se le han pedido (historial).
-- 2) Trigger: cada insumo que se pida a un proveedor queda vinculado solo.
-- No borra nada. Se puede correr más de una vez sin duplicar vínculos.

-- 0) Verificación: la tabla debe tener las columnas que usa este script.
do $$
begin
  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'group_ingredient_proveedores'
        and column_name in ('ingredient_id', 'proveedor_id')) <> 2 then
    raise exception 'group_ingredient_proveedores no tiene las columnas ingredient_id y proveedor_id: no se aplicó nada';
  end if;
end $$;

-- 1) Historial: vínculos desde los pedidos existentes
insert into public.group_ingredient_proveedores (ingredient_id, proveedor_id)
select distinct gi.id, o.proveedor_id
from public.orders o
join public.order_items oi on oi.order_id = o.id
join public.group_ingredients gi on gi.code = oi.ingredient_code
where o.proveedor_id is not null
  and not exists (
    select 1 from public.group_ingredient_proveedores gp
    where gp.ingredient_id = gi.id and gp.proveedor_id = o.proveedor_id
  );

-- 2) Trigger: vincula al guardar cada insumo de un pedido
create or replace function public.vincular_insumo_proveedor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.group_ingredient_proveedores (ingredient_id, proveedor_id)
  select gi.id, o.proveedor_id
  from public.orders o
  join public.group_ingredients gi on gi.code = new.ingredient_code
  where o.id = new.order_id
    and o.proveedor_id is not null
    and not exists (
      select 1 from public.group_ingredient_proveedores gp
      where gp.ingredient_id = gi.id and gp.proveedor_id = o.proveedor_id
    );
  return new;
end $$;

drop trigger if exists trg_vincular_insumo_proveedor on public.order_items;
create trigger trg_vincular_insumo_proveedor
after insert on public.order_items
for each row execute function public.vincular_insumo_proveedor();

-- Resultado: cuántos insumos quedó vinculado cada proveedor
select p.nombre as proveedor, count(gp.*) as insumos_vinculados
from public.proveedores p
left join public.group_ingredient_proveedores gp on gp.proveedor_id = p.id
group by p.nombre
order by p.nombre;
