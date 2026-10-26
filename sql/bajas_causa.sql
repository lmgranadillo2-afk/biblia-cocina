-- Bajas con causa obligatoria (26 oct 2026). No borra datos; se puede correr más de una vez. Las bajas anteriores quedan sin causa.
-- Causas: vencido (fecha de vencimiento), proveedor (pedido en que llegó), almacenamiento (dónde y qué falló),
-- preparacion (quién preparó) y prueba (para qué fue). Foto opcional: si se adjunta, se publica en el chat del grupo del punto.
-- Las bajas de "prueba" solo las ingresa o deniega un super admin, y le llega un mensaje directo para aprobarlas.

alter table public.bajas add column if not exists causa text;
alter table public.bajas add column if not exists causa_dato text;
alter table public.bajas add column if not exists pedido_id uuid references public.orders(id) on delete set null;
alter table public.bajas add column if not exists foto_path text;
alter table public.bajas drop constraint if exists bajas_causa_valida;
alter table public.bajas add constraint bajas_causa_valida
  check (causa is null or causa in ('vencido', 'proveedor', 'almacenamiento', 'preparacion', 'prueba'));

-- Nuevas bajas: causa y dato obligatorios. Resolver una de prueba: solo super admin.
create or replace function public.bajas_reglas_causa()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.causa is null then raise exception 'Elige la causa de la baja'; end if;
    if coalesce(trim(new.causa_dato), '') = '' and new.pedido_id is null then raise exception 'Falta el dato que pide la causa'; end if;
  elsif tg_op = 'UPDATE' then
    if old.causa = 'prueba' and new.status is distinct from old.status and not public.is_super_admin() then
      raise exception 'Las bajas de prueba solo las aprueba el super admin';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists bajas_reglas_causa on public.bajas;
create trigger bajas_reglas_causa before insert or update on public.bajas
  for each row execute function public.bajas_reglas_causa();

-- Aviso por chat directo a cada super admin cuando se registra una baja de prueba (con notificación al celular).
create or replace function public.baja_avisar_super_admin(p_baja uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare b public.bajas; v_sa uuid; v_conv uuid; v_n int := 0; v_lugar text;
begin
  select * into b from public.bajas where id = p_baja;
  if not found then raise exception 'Baja no encontrada'; end if;
  if b.created_by is distinct from auth.uid() then raise exception 'Solo quien registró la baja puede avisar'; end if;
  if b.causa <> 'prueba' then return 0; end if;
  select l.name || coalesce(' · ' || a.name, '') into v_lugar from public.locations l left join public.areas a on a.id = b.area_id where l.id = b.location_id;
  for v_sa in select id from public.profiles where is_super_admin and id <> auth.uid() loop
    insert into public.chat_conversaciones (tipo, usuario_a, usuario_b)
    values ('directo', least(auth.uid(), v_sa), greatest(auth.uid(), v_sa))
    on conflict (usuario_a, usuario_b) where tipo = 'directo' do nothing;
    select id into v_conv from public.chat_conversaciones
    where tipo = 'directo' and usuario_a = least(auth.uid(), v_sa) and usuario_b = greatest(auth.uid(), v_sa);
    insert into public.chat_mensajes (conversacion_id, autor_nombre, autor_area, texto)
    values (v_conv, b.creado_por_nombre, v_lugar,
      'Baja de PRUEBA por aprobar: ' || coalesce(b.codigo, '') || ' · ' || b.item_name || ' · ' || b.cantidad || ' ' || b.unidad
      || E'\nPara: ' || coalesce(b.causa_dato, '') || E'\nDetalle: ' || coalesce(b.motivo, '')
      || E'\n' || v_lugar || '. Revísala en Bajas de ese punto y área.');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke execute on function public.baja_avisar_super_admin(uuid) from public, anon;
grant execute on function public.baja_avisar_super_admin(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar las 4 columnas nuevas y el disparador
select column_name from information_schema.columns where table_schema = 'public' and table_name = 'bajas'
  and column_name in ('causa', 'causa_dato', 'pedido_id', 'foto_path')
union all select 'disparador: ' || tgname from pg_trigger where tgname = 'bajas_reglas_causa';
