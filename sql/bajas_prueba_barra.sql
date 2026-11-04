-- Bajas de prueba o degustación en Barra (todas las barras): las ingresa o deniega cualquier admin de esa Barra,
-- menos quien tenga profiles.no_aprueba_prueba_barra (chef@cantinadossantos.com, decisión de Miguel: solo las ve y no le llega el aviso).
-- En las demás áreas sigue igual: solo super admin. No borra datos; se puede correr más de una vez.

-- Causas nuevas solo para Barra: accidente (qué pasó y quién estaba) y mesero (lo regó el mesero: cuál).
alter table public.bajas drop constraint if exists bajas_causa_valida;
alter table public.bajas add constraint bajas_causa_valida
  check (causa is null or causa in ('vencido', 'proveedor', 'almacenamiento', 'preparacion', 'prueba', 'accidente', 'mesero'));

alter table public.profiles add column if not exists no_aprueba_prueba_barra boolean not null default false;
update public.profiles p set no_aprueba_prueba_barra = true
from auth.users u where u.id = p.id and lower(u.email) = 'chef@cantinadossantos.com';

create or replace function public.baja_prueba_puede_resolver(p_area uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.areas a where a.id = p_area and upper(trim(a.name)) like 'BARRA%') then
      (public.is_admin() or public.is_super_admin())
      and public.has_area_access(p_area)
      and not coalesce((select no_aprueba_prueba_barra from public.profiles where id = auth.uid()), false)
    else public.is_super_admin()
  end;
$$;
revoke execute on function public.baja_prueba_puede_resolver(uuid) from public, anon;
grant execute on function public.baja_prueba_puede_resolver(uuid) to authenticated, service_role;

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
    if new.causa in ('accidente', 'mesero') and not exists (select 1 from public.areas a where a.id = new.area_id and upper(trim(a.name)) like 'BARRA%') then
      raise exception 'Esa causa solo existe en Barra';
    end if;
  elsif tg_op = 'UPDATE' then
    if old.causa = 'prueba' and new.status is distinct from old.status and not public.baja_prueba_puede_resolver(old.area_id) then
      raise exception 'No puedes resolver esta baja de prueba: la aprueba un admin de Barra o, en otras áreas, el super admin';
    end if;
  end if;
  return new;
end;
$$;

-- El aviso por chat va a quien puede resolverla: en Barra, sus admins (menos el autor y los marcados); en otras áreas, los super admin.
create or replace function public.baja_avisar_super_admin(p_baja uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare b public.bajas; v_sa uuid; v_conv uuid; v_n int := 0; v_lugar text; v_barra boolean;
begin
  select * into b from public.bajas where id = p_baja;
  if not found then raise exception 'Baja no encontrada'; end if;
  if b.created_by is distinct from auth.uid() then raise exception 'Solo quien registró la baja puede avisar'; end if;
  if b.causa <> 'prueba' then return 0; end if;
  select l.name || coalesce(' · ' || a.name, '') into v_lugar from public.locations l left join public.areas a on a.id = b.area_id where l.id = b.location_id;
  v_barra := exists (select 1 from public.areas a where a.id = b.area_id and upper(trim(a.name)) like 'BARRA%');
  for v_sa in
    select p.id from public.profiles p
    where p.id <> auth.uid() and case
      when v_barra then (p.role = 'admin' or p.is_super_admin) and not p.no_aprueba_prueba_barra
        and exists (select 1 from public.user_areas ua where ua.user_id = p.id and ua.area_id = b.area_id)
      else p.is_super_admin end
  loop
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

notify pgrst, 'reload schema';

-- Debe mostrar solo a chef@cantinadossantos.com
select u.email from public.profiles p join auth.users u on u.id = p.id where p.no_aprueba_prueba_barra;
