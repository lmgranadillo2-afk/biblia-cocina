-- Módulo Horarios — paso 9: el registro se cierra TURNO POR TURNO (persona y día), no por día completo.
-- Correr después de horarios_1 a 8. No borra datos; se puede correr más de una vez.
--
-- Decisión de Miguel (23 oct 2026):
--  * El líder cierra el turno de cada persona cuando termina (ej. producción a la 1 p. m.). El día queda cerrado solo
--    cuando se cierra el último turno (horario_dias_cerrados se llena solo).
--  * Quincena abierta: un admin puede reabrir el turno de una persona; el líder lo corrige y lo vuelve a cerrar.
--  * Quincena cerrada: el admin HABILITA el turno de una persona (con motivo) y el LÍDER lo corrige; al cerrarlo se bloquea otra vez.
--  * Reemplaza la habilitación por día (horario_dias_habilitados queda sin uso; no se borra).

-- 1) Cierre por fila del registro
alter table public.horario_registro_dia
  add column if not exists cerrado boolean not null default false,
  add column if not exists cerrado_por text,
  add column if not exists cerrado_at timestamptz;
-- Lo que ya estaba en días cerrados queda cerrado
update public.horario_registro_dia r
set cerrado = true, cerrado_por = c.cerrado_por, cerrado_at = c.cerrado_at
from public.horario_dias_cerrados c
where c.area_id = r.area_id and c.fecha = r.fecha and not r.cerrado;

-- 2) Turnos habilitados para corrección (persona + día)
create table if not exists public.horario_turnos_habilitados (
  area_id uuid not null references public.areas(id) on delete cascade,
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  fecha date not null,
  habilitado_por text,
  motivo text not null,
  at timestamptz not null default now(),
  primary key (personal_id, fecha)
);
alter table public.horario_turnos_habilitados enable row level security;
drop policy if exists horario_turnos_habilitados_ver on public.horario_turnos_habilitados;
create policy horario_turnos_habilitados_ver on public.horario_turnos_habilitados for select to authenticated
  using (public.horario_puede_editar(area_id));

-- 3) Bloqueo por persona: algún día del rango está en quincena cerrada y ese turno no está habilitado.
create or replace function public.horario_bloqueado_persona(p_area uuid, p_personal uuid, p_desde date, p_hasta date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from generate_series(p_desde, p_hasta, interval '1 day') g(d)
    where public.horario_fecha_bloqueada(p_area, g.d::date)
      and not exists (select 1 from public.horario_turnos_habilitados h where h.personal_id = p_personal and h.fecha = g.d::date));
$$;
create or replace function public.horario_casilla_editable(p_semana uuid, p_dia smallint, p_personal uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.horario_semanas s
    where s.id = p_semana and s.estado = 'borrador' and public.horario_puede_editar(s.area_id)
      and not public.horario_bloqueado_persona(s.area_id, p_personal, s.lunes + (p_dia - 1), s.lunes + (p_dia - 1)));
$$;
revoke execute on function public.horario_bloqueado_persona(uuid, uuid, date, date) from public, anon;
revoke execute on function public.horario_casilla_editable(uuid, smallint, uuid) from public, anon;
grant execute on function public.horario_bloqueado_persona(uuid, uuid, date, date) to authenticated, service_role;
grant execute on function public.horario_casilla_editable(uuid, smallint, uuid) to authenticated, service_role;

do $$
declare t text;
begin
  foreach t in array array['horario_asignaciones', 'horario_tarea_asignaciones'] loop
    execute format('drop policy if exists %I on public.%I', t || '_crear', t);
    execute format('drop policy if exists %I on public.%I', t || '_editar', t);
    execute format('drop policy if exists %I on public.%I', t || '_borrar', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.horario_casilla_editable(semana_id, dia, personal_id))', t || '_crear', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.horario_casilla_editable(semana_id, dia, personal_id)) with check (public.horario_casilla_editable(semana_id, dia, personal_id))', t || '_editar', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.horario_casilla_editable(semana_id, dia, personal_id))', t || '_borrar', t);
  end loop;
end $$;

-- Registro: se edita mientras la fila no esté cerrada; cerrar y reabrir solo con las funciones de abajo.
drop policy if exists horario_registro_dia_crear on public.horario_registro_dia;
drop policy if exists horario_registro_dia_editar on public.horario_registro_dia;
drop policy if exists horario_registro_dia_borrar on public.horario_registro_dia;
create policy horario_registro_dia_crear on public.horario_registro_dia for insert to authenticated
  with check (public.horario_puede_editar(area_id) and not cerrado and not public.horario_bloqueado_persona(area_id, personal_id, fecha, fecha));
create policy horario_registro_dia_editar on public.horario_registro_dia for update to authenticated
  using (public.horario_puede_editar(area_id) and not cerrado and not public.horario_bloqueado_persona(area_id, personal_id, fecha, fecha))
  with check (public.horario_puede_editar(area_id) and not cerrado and not public.horario_bloqueado_persona(area_id, personal_id, fecha, fecha));
create policy horario_registro_dia_borrar on public.horario_registro_dia for delete to authenticated
  using (public.horario_puede_editar(area_id) and not cerrado and not public.horario_bloqueado_persona(area_id, personal_id, fecha, fecha));

-- Novedades: bloqueadas si tocan días cerrados de esa persona que no estén habilitados.
drop policy if exists horario_novedades_crear on public.horario_novedades;
drop policy if exists horario_novedades_editar on public.horario_novedades;
drop policy if exists horario_novedades_borrar on public.horario_novedades;
create policy horario_novedades_crear on public.horario_novedades for insert to authenticated
  with check (public.horario_puede_editar(area_id) and not public.horario_bloqueado_persona(area_id, personal_id, desde, hasta));
create policy horario_novedades_editar on public.horario_novedades for update to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_bloqueado_persona(area_id, personal_id, desde, hasta))
  with check (public.horario_puede_editar(area_id) and not public.horario_bloqueado_persona(area_id, personal_id, desde, hasta));
create policy horario_novedades_borrar on public.horario_novedades for delete to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_bloqueado_persona(area_id, personal_id, desde, hasta));

-- 4) ¿Todos los turnos del día están cerrados? Turnos esperados = casillas con turno (sin novedad) + filas del registro.
create or replace function public.horario_actualizar_dia(p_area uuid, p_fecha date, p_nombre text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from public.horario_asignaciones a join public.horario_semanas s on s.id = a.semana_id
    where s.area_id = p_area and a.tipo <> 'descanso' and s.lunes + (a.dia - 1) = p_fecha
      and not exists (select 1 from public.horario_novedades n where n.personal_id = a.personal_id and n.tipo <> 'retardo' and p_fecha between n.desde and n.hasta)
      and not exists (select 1 from public.horario_registro_dia r where r.personal_id = a.personal_id and r.fecha = p_fecha and r.cerrado)
  ) or exists (select 1 from public.horario_registro_dia r where r.area_id = p_area and r.fecha = p_fecha and not r.cerrado) then
    delete from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha;
  else
    insert into public.horario_dias_cerrados (area_id, fecha, cerrado_por) values (p_area, p_fecha, p_nombre)
    on conflict (area_id, fecha) do nothing;
  end if;
end;
$$;
revoke execute on function public.horario_actualizar_dia(uuid, date, text) from public, anon;

-- 5) Cerrar el turno de una persona (admin o líder). La fila del registro ya debe existir (la app la guarda antes).
create or replace function public.horario_cerrar_turno(p_area uuid, p_personal uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
declare v_nombre text := public.nombre_usuario_actual();
begin
  if not public.horario_puede_editar(p_area) then raise exception 'Solo un admin o un líder de horarios puede cerrar turnos'; end if;
  if p_fecha > (now() at time zone 'America/Bogota')::date then raise exception 'No se puede cerrar un turno de un día que todavía no llega'; end if;
  if public.horario_bloqueado_persona(p_area, p_personal, p_fecha, p_fecha) then raise exception 'Ese turno está en una quincena cerrada'; end if;
  update public.horario_registro_dia set cerrado = true, cerrado_por = v_nombre, cerrado_at = now()
  where area_id = p_area and personal_id = p_personal and fecha = p_fecha;
  if not found then raise exception 'Primero guarda el registro de ese turno'; end if;
  insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
  select r.area_id, r.personal_id, 'retardo', r.fecha, r.fecha, 'Llegó ' || coalesce(r.minutos_tarde::text, '?') || ' min tarde (registro del día)', v_nombre
  from public.horario_registro_dia r
  where r.personal_id = p_personal and r.fecha = p_fecha and r.estado = 'tarde'
    and not exists (select 1 from public.horario_novedades n where n.personal_id = r.personal_id and n.tipo = 'retardo' and n.desde = r.fecha);
  delete from public.horario_turnos_habilitados where personal_id = p_personal and fecha = p_fecha;
  perform public.horario_actualizar_dia(p_area, p_fecha, v_nombre);
end;
$$;

-- Cerrar todos los turnos pendientes del día (las filas ya deben existir).
create or replace function public.horario_cerrar_dia(p_area uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if not public.horario_puede_editar(p_area) then raise exception 'Solo un admin o un líder de horarios puede cerrar turnos'; end if;
  for r in select personal_id from public.horario_registro_dia
           where area_id = p_area and fecha = p_fecha and not cerrado
             and not public.horario_bloqueado_persona(p_area, personal_id, p_fecha, p_fecha) loop
    perform public.horario_cerrar_turno(p_area, r.personal_id, p_fecha);
  end loop;
  perform public.horario_actualizar_dia(p_area, p_fecha, public.nombre_usuario_actual());
end;
$$;

-- Reabrir el turno de una persona (solo admin, fuera de una quincena cerrada).
create or replace function public.horario_reabrir_turno(p_area uuid, p_personal uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then raise exception 'Solo un admin puede reabrir un turno'; end if;
  if public.horario_fecha_bloqueada(p_area, p_fecha) then raise exception 'Ese día está en una quincena cerrada: habilita el turno para corrección'; end if;
  update public.horario_registro_dia set cerrado = false where area_id = p_area and personal_id = p_personal and fecha = p_fecha;
  perform public.horario_actualizar_dia(p_area, p_fecha, public.nombre_usuario_actual());
end;
$$;

-- Habilitar el turno de una persona en una quincena cerrada (solo admin, con motivo). El líder lo corrige y lo vuelve a cerrar.
create or replace function public.horario_habilitar_turno(p_area uuid, p_personal uuid, p_fecha date, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_nombre text := public.nombre_usuario_actual(); v_persona text;
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then raise exception 'Solo un admin puede habilitar un turno para corrección'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Escribe qué hay que corregir'; end if;
  if not public.horario_fecha_bloqueada(p_area, p_fecha) then raise exception 'Ese día no está en una quincena cerrada: reabre el turno'; end if;
  select nombre into v_persona from public.horario_personal where id = p_personal and area_id = p_area;
  if v_persona is null then raise exception 'No encontré a esa persona en el área'; end if;
  insert into public.horario_turnos_habilitados (area_id, personal_id, fecha, habilitado_por, motivo) values (p_area, p_personal, p_fecha, v_nombre, trim(p_motivo))
  on conflict (personal_id, fecha) do update set habilitado_por = excluded.habilitado_por, motivo = excluded.motivo, at = now();
  update public.horario_registro_dia set cerrado = false where personal_id = p_personal and fecha = p_fecha;
  insert into public.horario_cambios_cierre (area_id, fecha, que, por) values (p_area, p_fecha, 'Turno de ' || v_persona || ' habilitado para corrección: ' || trim(p_motivo), v_nombre);
  perform public.horario_actualizar_dia(p_area, p_fecha, v_nombre);
end;
$$;

-- El día completo ya no se reabre ni se habilita: se hace turno por turno.
create or replace function public.horario_reabrir_dia(p_area uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
begin
  raise exception 'Ahora se reabre turno por turno';
end;
$$;

revoke execute on function public.horario_cerrar_turno(uuid, uuid, date) from public, anon;
revoke execute on function public.horario_reabrir_turno(uuid, uuid, date) from public, anon;
revoke execute on function public.horario_habilitar_turno(uuid, uuid, date, text) from public, anon;
grant execute on function public.horario_cerrar_turno(uuid, uuid, date) to authenticated, service_role;
grant execute on function public.horario_reabrir_turno(uuid, uuid, date) to authenticated, service_role;
grant execute on function public.horario_habilitar_turno(uuid, uuid, date, text) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar la tabla nueva con RLS activo (true) y cuántos turnos quedaron cerrados de días ya cerrados
select 'horario_turnos_habilitados' as que, (select c.relrowsecurity::text from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'horario_turnos_habilitados') as valor
union all
select 'turnos cerrados', count(*)::text from public.horario_registro_dia where cerrado;
