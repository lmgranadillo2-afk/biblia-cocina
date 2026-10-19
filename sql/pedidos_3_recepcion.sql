-- Pedidos · Paso 3: recepción (Recibido / Por recibir) + seguimiento de atrasados
-- Un pedido aprobado y enviado queda "por recibir" hasta que alguien del área lo marca como recibido.
-- Si pasa de 2 días (o de la fecha esperada que se anotó) sale como atrasado; se le puede registrar seguimiento.
-- No borra nada. Se puede correr más de una vez.

-- 1) Columnas de recepción y fecha esperada de entrega
alter table public.orders
  add column if not exists recibido boolean not null default false,
  add column if not exists recibido_at timestamptz,
  add column if not exists recibido_por text,
  add column if not exists recibido_nota text,
  add column if not exists entrega_esperada date;

-- 2) Pedidos ya enviados hace más de 7 días: se dan por recibidos (histórico),
--    para que no aparezcan todos como atrasados. Los de la última semana quedan por recibir.
update public.orders
set recibido = true, recibido_at = enviado_at, recibido_por = 'Histórico'
where enviado = true and recibido = false
  and enviado_at < now() - interval '7 days';

-- 3) Seguimientos de pedidos que no han llegado (historial para auditoría)
create table if not exists public.order_seguimientos (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  nota text not null,
  entrega_esperada date,
  created_by uuid default auth.uid(),
  creado_por_nombre text,
  created_at timestamptz not null default now()
);
create index if not exists order_seguimientos_order_idx on public.order_seguimientos(order_id);

alter table public.order_seguimientos enable row level security;
drop policy if exists "seguimientos: ver con acceso al área" on public.order_seguimientos;
create policy "seguimientos: ver con acceso al área" on public.order_seguimientos
  for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and public.has_area_access(o.area_id)));
-- Sin políticas de insert/update/delete: solo se escribe con la función de abajo.

-- Nombre de quien hace la acción (perfil, o correo si no tiene nombre)
create or replace function public.nombre_usuario_actual()
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select nullif(trim(p.name), '') from public.profiles p where p.id = auth.uid()),
    (select u.email from auth.users u where u.id = auth.uid()));
$$;

-- 4) Marcar recibido: cualquier usuario con acceso al área
create or replace function public.marcar_pedido_recibido(p_order_id uuid, p_nota text default null)
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
  if o.status <> 'aprobado' or not o.enviado then raise exception 'Solo se puede recibir un pedido aprobado y enviado'; end if;
  if o.recibido then raise exception 'Este pedido ya está marcado como recibido'; end if;

  update public.orders
  set recibido = true, recibido_at = now(), recibido_por = public.nombre_usuario_actual(),
      recibido_nota = nullif(trim(p_nota), '')
  where id = p_order_id;
end $$;

-- 5) Desmarcar recibido (por si se marcó por error): solo admin con acceso al área
create or replace function public.desmarcar_pedido_recibido(p_order_id uuid)
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
  if not (public.is_admin() and public.has_area_access(o.area_id)) then raise exception 'Solo un admin puede desmarcar'; end if;

  update public.orders
  set recibido = false, recibido_at = null, recibido_por = null, recibido_nota = null
  where id = p_order_id;
end $$;

-- 6) Registrar seguimiento de un pedido por recibir (nota + nueva fecha esperada opcional)
create or replace function public.registrar_seguimiento_pedido(p_order_id uuid, p_nota text, p_entrega_esperada date default null)
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
  if o.status <> 'aprobado' or not o.enviado or o.recibido then raise exception 'Solo se hace seguimiento a pedidos enviados que no han llegado'; end if;
  if nullif(trim(p_nota), '') is null then raise exception 'Escribe qué pasó con el pedido'; end if;

  insert into public.order_seguimientos (order_id, nota, entrega_esperada, created_by, creado_por_nombre)
  values (p_order_id, trim(p_nota), p_entrega_esperada, auth.uid(), public.nombre_usuario_actual());

  if p_entrega_esperada is not null then
    update public.orders set entrega_esperada = p_entrega_esperada where id = p_order_id;
  end if;
end $$;

revoke all on function public.nombre_usuario_actual() from public, anon;
revoke all on function public.marcar_pedido_recibido(uuid, text) from public, anon;
revoke all on function public.desmarcar_pedido_recibido(uuid) from public, anon;
revoke all on function public.registrar_seguimiento_pedido(uuid, text, date) from public, anon;
grant execute on function public.marcar_pedido_recibido(uuid, text) to authenticated;
grant execute on function public.desmarcar_pedido_recibido(uuid) to authenticated;
grant execute on function public.registrar_seguimiento_pedido(uuid, text, date) to authenticated;
grant select on public.order_seguimientos to authenticated;

notify pgrst, 'reload schema';

-- Resultado: pedidos que quedaron por recibir (enviados en los últimos 7 días)
select codigo, proveedor, enviado_at
from public.orders
where enviado = true and recibido = false
order by enviado_at desc;
