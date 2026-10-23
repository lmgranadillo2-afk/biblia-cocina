-- Módulo Horarios — paso 6: cierre de quincena. Correr después de horarios_1 a 5. No borra datos; se puede correr más de una vez.
--
-- Antes de cada nómina el líder verifica la quincena (días del registro cerrados, semanas publicadas) y la cierra.
-- Con la quincena cerrada, los líderes ya no pueden cambiar el horario, el registro ni las novedades de esos días (lo bloquea la base de datos).
-- Un admin SÍ puede corregirlos directamente (decisión de Miguel): cada cambio queda en horario_cambios_cierre y la pre-nómina lo avisa.
-- Un admin también puede reabrir la quincena, con motivo; queda en el historial.

create table if not exists public.horario_quincenas_cerradas (
  area_id uuid not null references public.areas(id) on delete cascade,
  desde date not null,
  hasta date not null,
  cerrado_por text,
  cerrado_at timestamptz not null default now(),
  primary key (area_id, desde),
  check (hasta >= desde)
);
create table if not exists public.horario_quincenas_historial (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  desde date not null,
  hasta date not null,
  accion text not null check (accion in ('cerrar', 'reabrir')),
  por text,
  motivo text,
  at timestamptz not null default now()
);
alter table public.horario_quincenas_cerradas enable row level security;
alter table public.horario_quincenas_historial enable row level security;
drop policy if exists horario_quincenas_cerradas_ver on public.horario_quincenas_cerradas;
create policy horario_quincenas_cerradas_ver on public.horario_quincenas_cerradas for select to authenticated
  using (public.has_area_access(area_id));
drop policy if exists horario_quincenas_historial_ver on public.horario_quincenas_historial;
create policy horario_quincenas_historial_ver on public.horario_quincenas_historial for select to authenticated
  using (public.horario_puede_editar(area_id));
-- Escritura solo con las funciones de abajo.

-- ¿Ese día (o rango) está dentro de una quincena cerrada?
create or replace function public.horario_fecha_bloqueada(p_area uuid, p_fecha date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.horario_quincenas_cerradas q where q.area_id = p_area and p_fecha between q.desde and q.hasta);
$$;
create or replace function public.horario_rango_bloqueado(p_area uuid, p_desde date, p_hasta date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.horario_quincenas_cerradas q where q.area_id = p_area and q.desde <= p_hasta and q.hasta >= p_desde);
$$;
-- Para quien edita: bloqueado si está en una quincena cerrada y NO es admin (los admin corrigen y queda registrado).
create or replace function public.horario_bloqueado_para_mi(p_area uuid, p_desde date, p_hasta date)
returns boolean language sql stable security definer set search_path = public as $$
  select public.horario_rango_bloqueado(p_area, p_desde, p_hasta) and not (public.is_admin() or public.is_super_admin());
$$;
-- Casilla editable: semana en borrador, admin o líder, y el día no está bloqueado para quien edita.
create or replace function public.horario_casilla_editable(p_semana uuid, p_dia smallint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.horario_semanas s
    where s.id = p_semana and s.estado = 'borrador' and public.horario_puede_editar(s.area_id)
      and not public.horario_bloqueado_para_mi(s.area_id, s.lunes + (p_dia - 1), s.lunes + (p_dia - 1)));
$$;
revoke execute on function public.horario_fecha_bloqueada(uuid, date) from public, anon;
revoke execute on function public.horario_rango_bloqueado(uuid, date, date) from public, anon;
revoke execute on function public.horario_casilla_editable(uuid, smallint) from public, anon;
revoke execute on function public.horario_bloqueado_para_mi(uuid, date, date) from public, anon;
grant execute on function public.horario_bloqueado_para_mi(uuid, date, date) to authenticated, service_role;
grant execute on function public.horario_fecha_bloqueada(uuid, date) to authenticated, service_role;
grant execute on function public.horario_rango_bloqueado(uuid, date, date) to authenticated, service_role;
grant execute on function public.horario_casilla_editable(uuid, smallint) to authenticated, service_role;

-- Casillas y tareas: además de la semana en borrador, el día no puede estar en una quincena cerrada.
do $$
declare t text;
begin
  foreach t in array array['horario_asignaciones', 'horario_tarea_asignaciones'] loop
    execute format('drop policy if exists %I on public.%I', t || '_crear', t);
    execute format('drop policy if exists %I on public.%I', t || '_editar', t);
    execute format('drop policy if exists %I on public.%I', t || '_borrar', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.horario_casilla_editable(semana_id, dia))', t || '_crear', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.horario_casilla_editable(semana_id, dia)) with check (public.horario_casilla_editable(semana_id, dia))', t || '_editar', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.horario_casilla_editable(semana_id, dia))', t || '_borrar', t);
  end loop;
end $$;

-- Registro del día: tampoco en quincena cerrada.
drop policy if exists horario_registro_dia_crear on public.horario_registro_dia;
drop policy if exists horario_registro_dia_editar on public.horario_registro_dia;
drop policy if exists horario_registro_dia_borrar on public.horario_registro_dia;
create policy horario_registro_dia_crear on public.horario_registro_dia for insert to authenticated
  with check (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha) and not public.horario_bloqueado_para_mi(area_id, fecha, fecha));
create policy horario_registro_dia_editar on public.horario_registro_dia for update to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha) and not public.horario_bloqueado_para_mi(area_id, fecha, fecha))
  with check (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha) and not public.horario_bloqueado_para_mi(area_id, fecha, fecha));
create policy horario_registro_dia_borrar on public.horario_registro_dia for delete to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha) and not public.horario_bloqueado_para_mi(area_id, fecha, fecha));

-- Novedades: no se crean, cambian ni quitan si tocan una quincena cerrada.
drop policy if exists horario_novedades_crear on public.horario_novedades;
drop policy if exists horario_novedades_editar on public.horario_novedades;
drop policy if exists horario_novedades_borrar on public.horario_novedades;
create policy horario_novedades_crear on public.horario_novedades for insert to authenticated
  with check (public.horario_puede_editar(area_id) and not public.horario_bloqueado_para_mi(area_id, desde, hasta));
create policy horario_novedades_editar on public.horario_novedades for update to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_bloqueado_para_mi(area_id, desde, hasta))
  with check (public.horario_puede_editar(area_id) and not public.horario_bloqueado_para_mi(area_id, desde, hasta));
create policy horario_novedades_borrar on public.horario_novedades for delete to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_bloqueado_para_mi(area_id, desde, hasta));

-- Reabrir un día del registro: no si su quincena está cerrada.
create or replace function public.horario_reabrir_dia(p_area uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin puede reabrir un día cerrado';
  end if;
  delete from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha;
end;
$$;

-- Cerrar la quincena (admin o líder). Valida que todo esté listo.
create or replace function public.horario_cerrar_quincena(p_area uuid, p_desde date, p_hasta date)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_nombre text := public.nombre_usuario_actual();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_fin date := case when extract(day from p_desde) = 1 then p_desde + 14 else (date_trunc('month', p_desde) + interval '1 month - 1 day')::date end;
  v_dias text;
  v_semanas text;
begin
  if not public.horario_puede_editar(p_area) then raise exception 'Solo un admin o un líder de horarios puede cerrar la quincena'; end if;
  if extract(day from p_desde) not in (1, 16) or p_hasta <> v_fin then raise exception 'Las quincenas van del 1 al 15 y del 16 al fin de mes'; end if;
  if p_hasta > v_hoy then raise exception 'La quincena todavía no termina'; end if;
  -- Semanas sin publicar que tocan la quincena
  select string_agg(to_char(s.lunes, 'DD/MM'), ', ' order by s.lunes) into v_semanas
  from public.horario_semanas s
  where s.area_id = p_area and s.estado <> 'publicada' and s.lunes <= p_hasta and s.lunes + 6 >= p_desde;
  if v_semanas is not null then raise exception 'Hay semanas sin publicar (desde el %)', v_semanas; end if;
  -- Días con turnos que no se cerraron en el registro
  select string_agg(to_char(f, 'DD/MM'), ', ' order by f) into v_dias
  from (
    select distinct s.lunes + (a.dia - 1) as f
    from public.horario_asignaciones a join public.horario_semanas s on s.id = a.semana_id
    where s.area_id = p_area and a.tipo <> 'descanso' and s.lunes + (a.dia - 1) between p_desde and p_hasta
  ) x
  where not exists (select 1 from public.horario_dias_cerrados c where c.area_id = p_area and c.fecha = x.f);
  if v_dias is not null then raise exception 'Faltan días por cerrar en el registro: %', v_dias; end if;
  insert into public.horario_quincenas_cerradas (area_id, desde, hasta, cerrado_por) values (p_area, p_desde, p_hasta, v_nombre)
  on conflict (area_id, desde) do nothing;
  insert into public.horario_quincenas_historial (area_id, desde, hasta, accion, por) values (p_area, p_desde, p_hasta, 'cerrar', v_nombre);
end;
$$;

-- Reabrir la quincena: solo admin, con motivo.
create or replace function public.horario_reabrir_quincena(p_area uuid, p_desde date, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_hasta date;
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin puede reabrir una quincena';
  end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Escribe el motivo para reabrir'; end if;
  delete from public.horario_quincenas_cerradas where area_id = p_area and desde = p_desde returning hasta into v_hasta;
  if v_hasta is null then raise exception 'Esa quincena no está cerrada'; end if;
  insert into public.horario_quincenas_historial (area_id, desde, hasta, accion, por, motivo)
  values (p_area, p_desde, v_hasta, 'reabrir', public.nombre_usuario_actual(), trim(p_motivo));
end;
$$;
revoke execute on function public.horario_cerrar_quincena(uuid, date, date) from public, anon;
revoke execute on function public.horario_reabrir_quincena(uuid, date, text) from public, anon;
grant execute on function public.horario_cerrar_quincena(uuid, date, date) to authenticated, service_role;
grant execute on function public.horario_reabrir_quincena(uuid, date, text) to authenticated, service_role;

-- Registro de cambios hechos en días de una quincena cerrada (solo los admin pueden hacerlos).
create table if not exists public.horario_cambios_cierre (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  fecha date not null,
  que text not null,
  por text,
  at timestamptz not null default now()
);
create index if not exists horario_cambios_cierre_idx on public.horario_cambios_cierre (area_id, fecha);
alter table public.horario_cambios_cierre enable row level security;
drop policy if exists horario_cambios_cierre_ver on public.horario_cambios_cierre;
create policy horario_cambios_cierre_ver on public.horario_cambios_cierre for select to authenticated
  using (public.horario_puede_editar(area_id));

create or replace function public.horario_registrar_cambio_cierre()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_area uuid; v_fecha date; v_hasta date; v_que text; v_nombre text; v_antes text; v_despues text;
  o jsonb := case when TG_OP <> 'INSERT' then to_jsonb(OLD) end;
  n jsonb := case when TG_OP <> 'DELETE' then to_jsonb(NEW) end;
  x jsonb := coalesce(n, o);
begin
  if TG_TABLE_NAME in ('horario_asignaciones', 'horario_tarea_asignaciones') then
    select s.area_id, s.lunes + ((x->>'dia')::int - 1) into v_area, v_fecha
    from public.horario_semanas s where s.id = (x->>'semana_id')::uuid;
  else
    v_area := (x->>'area_id')::uuid;
    v_fecha := coalesce((x->>'fecha')::date, (x->>'desde')::date);
  end if;
  if TG_TABLE_NAME = 'horario_novedades' then
    v_fecha := least(coalesce((n->>'desde')::date, (o->>'desde')::date), coalesce((o->>'desde')::date, (n->>'desde')::date));
    v_hasta := greatest(coalesce((n->>'hasta')::date, (o->>'hasta')::date), coalesce((o->>'hasta')::date, (n->>'hasta')::date));
  end if;
  if v_area is null or not public.horario_rango_bloqueado(v_area, v_fecha, coalesce(v_hasta, v_fecha)) then return null; end if;
  -- Adjuntar un soporte a una novedad no cambia horas: no cuenta como cambio después del cierre.
  if TG_OP = 'UPDATE' and TG_TABLE_NAME = 'horario_novedades' and (o - 'soportes') = (n - 'soportes') then return null; end if;
  select nombre into v_nombre from public.horario_personal where id = (x->>'personal_id')::uuid;

  if TG_TABLE_NAME = 'horario_asignaciones' then
    v_antes := case when o is null then 'vacío' when o->>'tipo' = 'descanso' then 'descanso' else coalesce(o->>'codigo', '?') end;
    v_despues := case when n is null then 'vacío' when n->>'tipo' = 'descanso' then 'descanso' else coalesce(n->>'codigo', '?') end;
    if v_antes = v_despues then return null; end if;
    v_que := format('Horario de %s: %s → %s', v_nombre, v_antes, v_despues);
  elsif TG_TABLE_NAME = 'horario_tarea_asignaciones' then
    v_que := format('%s: %s → %s', (select nombre from public.horario_tareas where id = (x->>'tarea_id')::uuid),
      coalesce((select nombre from public.horario_personal where id = (o->>'personal_id')::uuid), 'nadie'),
      coalesce((select nombre from public.horario_personal where id = (n->>'personal_id')::uuid), 'nadie'));
  elsif TG_TABLE_NAME = 'horario_registro_dia' then
    v_antes := case when o is null then 'sin registro' else (o->>'estado') || ' ' || coalesce(o->>'horas_reales', '?') || ' h' end;
    v_despues := case when n is null then 'sin registro' else (n->>'estado') || ' ' || coalesce(n->>'horas_reales', '?') || ' h' end;
    if v_antes = v_despues and coalesce(o->>'nota', '') = coalesce(n->>'nota', '') and coalesce(o->>'minutos_tarde', '') = coalesce(n->>'minutos_tarde', '') then return null; end if;
    v_que := format('Registro de %s: %s → %s', v_nombre, v_antes, v_despues);
  elsif TG_TABLE_NAME = 'horario_novedades' then
    v_que := format('Novedad %s: %s %s (%s a %s)', case TG_OP when 'INSERT' then 'agregada' when 'DELETE' then 'quitada' else 'cambiada' end,
      v_nombre, x->>'tipo', to_char((x->>'desde')::date, 'DD/MM'), to_char((x->>'hasta')::date, 'DD/MM'));
  elsif TG_TABLE_NAME = 'horario_dias_cerrados' then
    v_que := case TG_OP when 'DELETE' then 'Día reabierto en el registro' else 'Día cerrado otra vez en el registro' end;
  end if;
  insert into public.horario_cambios_cierre (area_id, fecha, que, por) values (v_area, v_fecha, v_que, public.nombre_usuario_actual());
  return null;
end;
$$;
revoke execute on function public.horario_registrar_cambio_cierre() from public, anon;

do $$
declare t text;
begin
  foreach t in array array['horario_asignaciones', 'horario_tarea_asignaciones', 'horario_registro_dia', 'horario_novedades', 'horario_dias_cerrados'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_cambio_cierre', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.horario_registrar_cambio_cierre()', t || '_cambio_cierre', t);
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar las 3 tablas nuevas con RLS activo (true)
select c.relname as tabla, c.relrowsecurity as rls_activo
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('horario_quincenas_cerradas', 'horario_quincenas_historial', 'horario_cambios_cierre')
order by 1;
