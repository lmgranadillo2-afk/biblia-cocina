-- Pedidos: "No llegó" y "Llegó incompleto" en la recepción (decisiones de Miguel, 9 nov 2026).
-- No llegó: pide motivo; el pedido vuelve a "Por enviar" (al mismo proveedor) con marca roja, queda en el historial
--   y avisa por chat directo a los admin del área.
-- Llegó incompleto: se marcan los insumos que faltaron y cuánto llegó; el pedido queda Recibido (incompleto) y se crea
--   solo un pedido nuevo, aprobado y por enviar, con lo que faltó ("Faltante de PED-…"). También avisa a los admin.
-- Lo puede usar cualquiera con acceso al área (igual que "Recibido"). No borra datos; se puede correr más de una vez.
alter table public.orders add column if not exists no_llego_at timestamptz;
alter table public.orders add column if not exists no_llego_por text;
alter table public.orders add column if not exists no_llego_motivo text;
alter table public.orders add column if not exists incompleto boolean not null default false;
alter table public.orders add column if not exists pedido_origen_id uuid references public.orders(id) on delete set null;
alter table public.orders add column if not exists pedido_origen_codigo text;
alter table public.order_items add column if not exists cantidad_recibida numeric;

-- Mensaje directo a los admin del área (menos quien hace el cambio).
create or replace function public.pedido_avisar_admins(p_order_id uuid, p_texto text)
returns int language plpgsql security definer set search_path = public as $$
declare o public.orders; v_admin uuid; v_conv uuid; v_n int := 0; v_lugar text;
begin
  select * into o from public.orders where id = p_order_id;
  if not found or auth.uid() is null then return 0; end if;
  select l.name || ' · ' || a.name into v_lugar from public.areas a join public.locations l on l.id = a.location_id where a.id = o.area_id;
  for v_admin in
    select p.id from public.profiles p join public.user_areas ua on ua.user_id = p.id and ua.area_id = o.area_id
    where (p.role = 'admin' or p.is_super_admin) and p.id <> auth.uid()
  loop
    insert into public.chat_conversaciones (tipo, usuario_a, usuario_b)
    values ('directo', least(auth.uid(), v_admin), greatest(auth.uid(), v_admin))
    on conflict (usuario_a, usuario_b) where tipo = 'directo' do nothing;
    select id into v_conv from public.chat_conversaciones
    where tipo = 'directo' and usuario_a = least(auth.uid(), v_admin) and usuario_b = greatest(auth.uid(), v_admin);
    insert into public.chat_mensajes (conversacion_id, autor_nombre, autor_area, texto)
    values (v_conv, public.nombre_usuario_actual(), v_lugar, p_texto);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke execute on function public.pedido_avisar_admins(uuid, text) from public, anon, authenticated;

create or replace function public.pedido_no_llego(p_order_id uuid, p_motivo text)
returns int language plpgsql security definer set search_path = public as $$
declare o public.orders; v_motivo text := nullif(btrim(p_motivo), '');
begin
  select * into o from public.orders where id = p_order_id;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if not public.has_area_access(o.area_id) then raise exception 'No tienes acceso a esta área'; end if;
  if o.status <> 'aprobado' or not o.enviado or o.recibido then raise exception 'Solo aplica a pedidos enviados que no se han recibido'; end if;
  if v_motivo is null then raise exception 'Escribe por qué no llegó'; end if;
  insert into public.order_seguimientos (order_id, nota, created_by, creado_por_nombre)
  values (p_order_id, 'No llegó: ' || v_motivo || '. Vuelve a por enviar.', auth.uid(), public.nombre_usuario_actual());
  update public.orders set enviado = false, enviado_at = null, enviado_por = null, entrega_esperada = null,
    no_llego_at = now(), no_llego_por = public.nombre_usuario_actual(), no_llego_motivo = v_motivo
  where id = p_order_id;
  return public.pedido_avisar_admins(p_order_id, 'Pedido ' || coalesce(o.codigo, '') || ' de ' || coalesce(o.proveedor, '') || ' NO LLEGÓ.'
    || E'\nMotivo: ' || v_motivo || E'\nQuedó otra vez por enviar: revísalo en Pedidos.');
end $$;
revoke execute on function public.pedido_no_llego(uuid, text) from public, anon;
grant execute on function public.pedido_no_llego(uuid, text) to authenticated, service_role;

-- p_items: [{ "id": <order_item>, "recibida": <cantidad que sí llegó> }] solo de los insumos que faltaron.
create or replace function public.pedido_llego_incompleto(p_order_id uuid, p_items jsonb, p_nota text default null)
returns text language plpgsql security definer set search_path = public as $$
declare o public.orders; it record; v_nuevo uuid; v_codigo text; v_n int := 0; v_lista text := '';
begin
  select * into o from public.orders where id = p_order_id;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if not public.has_area_access(o.area_id) then raise exception 'No tienes acceso a esta área'; end if;
  if o.status <> 'aprobado' or not o.enviado or o.recibido then raise exception 'Solo aplica a pedidos enviados que no se han recibido'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Marca qué insumos faltaron'; end if;

  insert into public.orders (location_id, area_id, fecha, semana_inicio, proveedor, proveedor_id, proveedor_telefono, proveedor_correo,
    status, resuelto_por, resuelto_at, created_by, creado_por_nombre, urgente, pedido_origen_id, pedido_origen_codigo)
  values (o.location_id, o.area_id, current_date, date_trunc('week', current_date)::date, o.proveedor, o.proveedor_id, o.proveedor_telefono, o.proveedor_correo,
    'aprobado', 'Faltante de ' || coalesce(o.codigo, 'pedido'), now(), auth.uid(), public.nombre_usuario_actual(), false, o.id, o.codigo)
  returning id, codigo into v_nuevo, v_codigo;

  for it in
    select oi.*, greatest(0, least(oi.cantidad, coalesce((x->>'recibida')::numeric, 0))) as recibida
    from jsonb_array_elements(p_items) x join public.order_items oi on oi.id = (x->>'id')::uuid and oi.order_id = p_order_id
  loop
    update public.order_items set cantidad_recibida = it.recibida where id = it.id;
    if it.cantidad - it.recibida > 0 then
      insert into public.order_items (order_id, ingredient_code, ingredient_name, categoria, cantidad, unidad, nota)
      values (v_nuevo, it.ingredient_code, it.ingredient_name, it.categoria, it.cantidad - it.recibida, it.unidad, 'Faltó en ' || coalesce(o.codigo, ''));
      v_n := v_n + 1;
      v_lista := v_lista || E'\n· ' || it.ingredient_name || ': faltó ' || trim(to_char(it.cantidad - it.recibida, 'FM999999990.##')) || ' ' || it.unidad;
    end if;
  end loop;
  if v_n = 0 then raise exception 'Los insumos marcados sí llegaron completos: usa "Llegó completo"'; end if;

  update public.orders set recibido = true, recibido_at = now(), recibido_por = public.nombre_usuario_actual(),
    recibido_nota = nullif(btrim(p_nota), ''), incompleto = true
  where id = p_order_id;
  -- El código del pedido nuevo lo pone el disparador; se lee después de insertar.
  select codigo into v_codigo from public.orders where id = v_nuevo;
  insert into public.order_seguimientos (order_id, nota, created_by, creado_por_nombre)
  values (p_order_id, 'Llegó incompleto. Faltantes en el pedido ' || coalesce(v_codigo, 'nuevo') || '.', auth.uid(), public.nombre_usuario_actual());
  perform public.pedido_avisar_admins(p_order_id, 'Pedido ' || coalesce(o.codigo, '') || ' de ' || coalesce(o.proveedor, '') || ' LLEGÓ INCOMPLETO.' || v_lista
    || E'\nSe creó el pedido ' || coalesce(v_codigo, '') || ' con lo que faltó, aprobado y por enviar.');
  return v_codigo;
end $$;
revoke execute on function public.pedido_llego_incompleto(uuid, jsonb, text) from public, anon;
grant execute on function public.pedido_llego_incompleto(uuid, jsonb, text) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar las dos funciones
select proname from pg_proc where proname in ('pedido_no_llego', 'pedido_llego_incompleto') order by proname;
