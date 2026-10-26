-- Desmarcar un pedido enviado por error: vuelve a aprobado y sin enviar. Solo admin (o super admin) con acceso al área.
-- Igual que marcar_pedido_enviado: no se abre la política de edición de pedidos; solo esta función cambia el envío.
create or replace function public.desmarcar_pedido_enviado(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders;
begin
  select * into o from public.orders where id = p_order_id;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if not (public.is_admin() or public.is_super_admin()) then raise exception 'Solo un admin puede desmarcar un envío'; end if;
  if not public.has_area_access(o.area_id) then raise exception 'No tienes acceso a esta área'; end if;
  if not o.enviado then raise exception 'Este pedido no está marcado como enviado'; end if;
  if o.recibido then raise exception 'Este pedido ya fue recibido: desmarca primero la recepción'; end if;
  update public.orders set enviado = false, enviado_at = null, enviado_por = null where id = p_order_id;
end $$;
revoke execute on function public.desmarcar_pedido_enviado(uuid) from public, anon;
grant execute on function public.desmarcar_pedido_enviado(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar la función
select proname from pg_proc where proname = 'desmarcar_pedido_enviado';
