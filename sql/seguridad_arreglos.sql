-- Arreglos de la revisión de seguridad (oct 2026). No borra datos: solo ajusta permisos y funciones.
-- Se puede correr más de una vez.

-- 1) Perfiles: solo el super admin cambia roles y datos de otros usuarios.
--    Antes: cualquier admin (de cualquier punto) podía cambiar el rol de cualquier usuario.
--    En la app, la pestaña Usuarios ya es solo del super admin, así que no cambia nada para nadie.
drop policy if exists "admin actualiza roles" on public.profiles;
drop policy if exists "super admin actualiza perfiles" on public.profiles;
create policy "super admin actualiza perfiles" on public.profiles
  for update using (public.is_super_admin()) with check (public.is_super_admin());

-- 2) Alerta de "misma receta el mismo día": solo responde sobre áreas a las que el usuario tiene acceso.
--    Antes respondía sobre cualquier área, incluso sin sesión.
create or replace function public.check_same_day_production(p_recipe_code text, p_fecha date, p_area_id uuid)
returns table(responsable text, created_at timestamp with time zone, cantidad_label text)
language sql
security definer
set search_path to 'public'
as $function$
  select responsable, created_at, cantidad_label
  from public.productions
  where recipe_code = p_recipe_code and fecha = p_fecha and status = 'activo' and area_id = p_area_id
    and public.has_area_access(p_area_id)
  order by created_at asc;
$function$;

-- 3) Creación de perfiles al registrarse: search_path fijo.
alter function public.handle_new_user() set search_path = public;

-- 4) Funciones que no debe poder llamar un visitante sin sesión.
--    Las que usa la app quedan para usuarios con sesión; las de trigger no las llama nadie
--    directamente (los triggers siguen funcionando igual).
revoke execute on function public.delete_location_cascade(uuid) from public, anon;
revoke execute on function public.check_same_day_production(text, date, uuid) from public, anon;
revoke execute on function public.admin_location_id() from public, anon;
revoke execute on function public.eventos_location_id() from public, anon;
grant execute on function public.delete_location_cascade(uuid) to authenticated, service_role;
grant execute on function public.check_same_day_production(text, date, uuid) to authenticated, service_role;
grant execute on function public.admin_location_id() to authenticated, service_role;
grant execute on function public.eventos_location_id() to authenticated, service_role;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.proteger_super_admin() from public, anon, authenticated;
revoke execute on function public.vincular_insumo_proveedor() from public, anon, authenticated;

-- 5) Marcar pedido como enviado: cualquiera con acceso al área (antes solo quien lo creó;
--    a los demás el WhatsApp se abría pero el pedido quedaba "sin enviar" sin avisar).
--    No se abre la política de edición de pedidos: solo esta función cambia el envío.
create or replace function public.marcar_pedido_enviado(p_order_id uuid)
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
  if not public.has_area_access(o.area_id) then raise exception 'No tienes acceso a esta área'; end if;
  if o.status <> 'aprobado' then raise exception 'Solo se envía un pedido aprobado'; end if;
  if o.enviado then raise exception 'Este pedido ya fue enviado'; end if;

  update public.orders
  set enviado = true, enviado_at = now(),
      enviado_por = coalesce((select nullif(trim(p.name), '') from public.profiles p where p.id = auth.uid()),
                             (select u.email from auth.users u where u.id = auth.uid()))
  where id = p_order_id;
end $$;
revoke execute on function public.marcar_pedido_enviado(uuid) from public, anon;
grant execute on function public.marcar_pedido_enviado(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Verificación: funciones security definer que todavía puede ejecutar un visitante sin sesión.
-- Deben quedar solo los helpers de permisos (is_admin, is_super_admin, has_area_access,
-- has_location_access, is_eventos_user): sin sesión siempre responden "no".
select p.proname as funcion_ejecutable_sin_sesion
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE')
order by 1;
