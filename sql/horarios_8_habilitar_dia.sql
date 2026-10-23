-- Módulo Horarios — paso 8: corregir un día de una quincena cerrada. Correr después de horarios_1 a 7.
-- No borra datos; se puede correr más de una vez.
--
-- Decisión de Miguel (23 oct 2026): el ADMIN no corrige. El admin HABILITA un día (con motivo) y el LÍDER hace la corrección.
-- Al volver a cerrar ese día en el registro, la habilitación se quita sola y el día queda bloqueado otra vez.
-- Mientras tanto cada cambio sigue quedando en horario_cambios_cierre y la pre-nómina lo avisa.

create table if not exists public.horario_dias_habilitados (
  area_id uuid not null references public.areas(id) on delete cascade,
  fecha date not null,
  habilitado_por text,
  motivo text not null,
  at timestamptz not null default now(),
  primary key (area_id, fecha)
);
alter table public.horario_dias_habilitados enable row level security;
drop policy if exists horario_dias_habilitados_ver on public.horario_dias_habilitados;
create policy horario_dias_habilitados_ver on public.horario_dias_habilitados for select to authenticated
  using (public.horario_puede_editar(area_id));
-- Escritura solo con las funciones de abajo.

-- Bloqueado: algún día del rango está en una quincena cerrada y no está habilitado. Ya no hay excepción para los admin.
create or replace function public.horario_bloqueado_para_mi(p_area uuid, p_desde date, p_hasta date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from generate_series(p_desde, p_hasta, interval '1 day') g(d)
    where public.horario_fecha_bloqueada(p_area, g.d::date)
      and not exists (select 1 from public.horario_dias_habilitados h where h.area_id = p_area and h.fecha = g.d::date));
$$;

-- Habilitar un día para que el líder lo corrija: solo admin, con motivo. También reabre el día en el registro.
create or replace function public.horario_habilitar_dia(p_area uuid, p_fecha date, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_nombre text := public.nombre_usuario_actual();
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin puede habilitar un día para corrección';
  end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Escribe qué hay que corregir'; end if;
  if not public.horario_fecha_bloqueada(p_area, p_fecha) then raise exception 'Ese día no está en una quincena cerrada'; end if;
  insert into public.horario_dias_habilitados (area_id, fecha, habilitado_por, motivo) values (p_area, p_fecha, v_nombre, trim(p_motivo))
  on conflict (area_id, fecha) do update set habilitado_por = excluded.habilitado_por, motivo = excluded.motivo, at = now();
  insert into public.horario_cambios_cierre (area_id, fecha, que, por)
  values (p_area, p_fecha, 'Día habilitado para corrección: ' || trim(p_motivo), v_nombre);
  delete from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha;
end;
$$;
revoke execute on function public.horario_habilitar_dia(uuid, date, text) from public, anon;
grant execute on function public.horario_habilitar_dia(uuid, date, text) to authenticated, service_role;

-- Cerrar el día (admin o líder): igual que antes, y además quita la habilitación de ese día.
create or replace function public.horario_cerrar_dia(p_area uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
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
  delete from public.horario_dias_habilitados where area_id = p_area and fecha = p_fecha;
end;
$$;

-- Reabrir un día del registro (admin): solo días fuera de una quincena cerrada; dentro, se usa "habilitar".
create or replace function public.horario_reabrir_dia(p_area uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin puede reabrir un día cerrado';
  end if;
  if public.horario_fecha_bloqueada(p_area, p_fecha) then
    raise exception 'Ese día está en una quincena cerrada: habilítalo para corrección';
  end if;
  delete from public.horario_dias_cerrados where area_id = p_area and fecha = p_fecha;
end;
$$;

notify pgrst, 'reload schema';

-- Debe mostrar la tabla nueva con RLS activo (true)
select c.relname as tabla, c.relrowsecurity as rls_activo
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'horario_dias_habilitados';
