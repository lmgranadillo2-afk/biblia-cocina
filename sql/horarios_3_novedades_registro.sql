-- Módulo Horarios — paso 3 (fase 2): novedades y registro del día. Correr después de horarios_1 y horarios_2.
-- No borra datos. Se puede correr más de una vez.
--
-- Decisiones de Miguel (23 oct 2026):
--  * El motivo de una ausencia (incapacidad = dato de salud) solo lo ven admin y líderes. El resto del área solo sabe
--    que esa persona "no viene" (función horario_ausencias, sin tipo ni nota).
--  * Novedades y registro del día solo los ven y manejan admin y líderes.
--  * Un día cerrado solo lo reabre un admin.

-- 1) Registro: estado de llegada, minutos tarde y si vino sin estar en el horario
alter table public.horario_registro_dia
  add column if not exists estado text not null default 'asistio',
  add column if not exists minutos_tarde int,
  add column if not exists extra boolean not null default false;
do $$ begin
  alter table public.horario_registro_dia add constraint horario_registro_estado_chk check (estado in ('asistio', 'tarde', 'falto'));
exception when duplicate_object then null; end $$;

-- 2) Días cerrados (un día cerrado bloquea su registro)
create table if not exists public.horario_dias_cerrados (
  area_id uuid not null references public.areas(id) on delete cascade,
  fecha date not null,
  cerrado_por text,
  cerrado_at timestamptz not null default now(),
  primary key (area_id, fecha)
);
alter table public.horario_dias_cerrados enable row level security;

create or replace function public.horario_dia_cerrado(p_area uuid, p_fecha date)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha);
$$;
revoke execute on function public.horario_dia_cerrado(uuid, date) from public, anon;
grant execute on function public.horario_dia_cerrado(uuid, date) to authenticated, service_role;

-- 3) Permisos: novedades y registro solo para admin y líderes; el registro de un día cerrado no se toca.
drop policy if exists horario_novedades_ver on public.horario_novedades;
create policy horario_novedades_ver on public.horario_novedades for select to authenticated
  using (public.horario_puede_editar(area_id));

drop policy if exists horario_registro_dia_ver on public.horario_registro_dia;
drop policy if exists horario_registro_dia_crear on public.horario_registro_dia;
drop policy if exists horario_registro_dia_editar on public.horario_registro_dia;
drop policy if exists horario_registro_dia_borrar on public.horario_registro_dia;
create policy horario_registro_dia_ver on public.horario_registro_dia for select to authenticated
  using (public.horario_puede_editar(area_id));
create policy horario_registro_dia_crear on public.horario_registro_dia for insert to authenticated
  with check (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha));
create policy horario_registro_dia_editar on public.horario_registro_dia for update to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha))
  with check (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha));
create policy horario_registro_dia_borrar on public.horario_registro_dia for delete to authenticated
  using (public.horario_puede_editar(area_id) and not public.horario_dia_cerrado(area_id, fecha));

drop policy if exists horario_dias_cerrados_ver on public.horario_dias_cerrados;
create policy horario_dias_cerrados_ver on public.horario_dias_cerrados for select to authenticated
  using (public.horario_puede_editar(area_id));
-- Cerrar / reabrir solo con las funciones de abajo (sin políticas de escritura).

-- 4) Ausencias para todo el área: quién no viene y qué días, SIN el motivo ni la nota.
create or replace function public.horario_ausencias(p_area uuid, p_desde date, p_hasta date)
returns table (personal_id uuid, desde date, hasta date)
language sql
stable
security definer
set search_path = public
as $$
  select n.personal_id, n.desde, n.hasta
  from public.horario_novedades n
  where public.has_area_access(p_area) and n.area_id = p_area
    and n.tipo <> 'retardo' and n.desde <= p_hasta and n.hasta >= p_desde;
$$;
revoke execute on function public.horario_ausencias(uuid, date, date) from public, anon;
grant execute on function public.horario_ausencias(uuid, date, date) to authenticated, service_role;

-- 5) Cerrar el día (admin o líder): bloquea el registro y anota los retardos como novedad.
create or replace function public.horario_cerrar_dia(p_area uuid, p_fecha date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_nombre text := public.nombre_usuario_actual();
begin
  if not public.horario_puede_editar(p_area) then raise exception 'Solo un admin o un líder de horarios puede cerrar el día'; end if;
  if p_fecha > (now() at time zone 'America/Bogota')::date then raise exception 'No se puede cerrar un día que todavía no llega'; end if;
  insert into public.horario_dias_cerrados (area_id, fecha, cerrado_por) values (p_area, p_fecha, v_nombre)
  on conflict (area_id, fecha) do nothing;
  insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
  select r.area_id, r.personal_id, 'retardo', r.fecha, r.fecha,
         'Llegó ' || coalesce(r.minutos_tarde::text, '?') || ' min tarde (registro del día)', v_nombre
  from public.horario_registro_dia r
  where r.area_id = p_area and r.fecha = p_fecha and r.estado = 'tarde'
    and not exists (select 1 from public.horario_novedades n
                    where n.personal_id = r.personal_id and n.tipo = 'retardo' and n.desde = r.fecha);
end;
$$;
revoke execute on function public.horario_cerrar_dia(uuid, date) from public, anon;
grant execute on function public.horario_cerrar_dia(uuid, date) to authenticated, service_role;

-- 6) Reabrir un día: solo un admin.
create or replace function public.horario_reabrir_dia(p_area uuid, p_fecha date)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin puede reabrir un día cerrado';
  end if;
  delete from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha;
end;
$$;
revoke execute on function public.horario_reabrir_dia(uuid, date) from public, anon;
grant execute on function public.horario_reabrir_dia(uuid, date) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar las 3 funciones nuevas y la tabla de días cerrados con RLS activo (true)
select 'funcion' as que, p.proname as nombre, null::boolean as rls_activo
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('horario_ausencias', 'horario_cerrar_dia', 'horario_reabrir_dia')
union all
select 'tabla', c.relname, c.relrowsecurity
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'horario_dias_cerrados';
