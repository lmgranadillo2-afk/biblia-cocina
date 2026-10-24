-- Módulo Horarios — paso 12: perfil de Recursos humanos y Horarios en todas las áreas. Correr después de horarios_1 a 11.
-- No borra datos; se puede correr más de una vez.
--
-- Decisiones de Miguel (24 oct 2026):
--  * Recursos humanos: perfil propio (profiles.es_rrhh) que ve SOLO lo de nómina en TODOS los puntos: horarios publicados,
--    novedades con soportes, registro del día, quincenas, pre-nómina y salarios. No ve recetas, pedidos, costeo ni Admin,
--    y no necesita accesos por punto/área. Se marca en Admin → Usuarios ("Recursos humanos").
--  * El módulo Horarios se activa en todas las áreas de todos los restaurantes (no en los puntos centrales Admin y Eventos).

-- 1) Perfil de Recursos humanos
alter table public.profiles add column if not exists es_rrhh boolean not null default false;

create or replace function public.es_rrhh()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select es_rrhh from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.es_rrhh() from public, anon;
grant execute on function public.es_rrhh() to authenticated, service_role;

-- Lectura de horarios: quien tiene acceso al área o Recursos humanos
create or replace function public.horario_puede_leer(p_area uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.has_area_access(p_area), false) or public.es_rrhh();
$$;
revoke execute on function public.horario_puede_leer(uuid) from public, anon;
grant execute on function public.horario_puede_leer(uuid) to authenticated, service_role;

-- Puntos y áreas: Recursos humanos los ve todos (solo lectura)
drop policy if exists rrhh_ver_locations on public.locations;
create policy rrhh_ver_locations on public.locations for select to authenticated using (public.es_rrhh());
drop policy if exists rrhh_ver_areas on public.areas;
create policy rrhh_ver_areas on public.areas for select to authenticated using (public.es_rrhh());

-- Configuración del área (personal, estaciones, turnos, tareas, reglas)
do $$
declare t text;
begin
  foreach t in array array['horario_config', 'horario_estaciones', 'horario_personal', 'horario_turnos', 'horario_tareas'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.horario_puede_leer(area_id))', t || '_ver', t);
  end loop;
end $$;

-- Semanas: Recursos humanos ve todas (publicadas y borradores) para la nómina
drop policy if exists horario_semanas_ver on public.horario_semanas;
create policy horario_semanas_ver on public.horario_semanas for select to authenticated
  using ((public.has_area_access(area_id) and (estado = 'publicada' or public.horario_puede_editar(area_id))) or public.es_rrhh());
create or replace function public.horario_puede_ver_semana(p_semana uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.horario_semanas s
    where s.id = p_semana and (public.es_rrhh() or (public.has_area_access(s.area_id)
      and (s.estado = 'publicada' or public.horario_puede_editar(s.area_id)))));
$$;

-- Novedades, registro, cierres, cambios y marcaciones: admin, líderes o Recursos humanos
do $$
declare t text;
begin
  foreach t in array array['horario_novedades', 'horario_registro_dia', 'horario_dias_cerrados', 'horario_quincenas_historial',
                           'horario_cambios_cierre', 'horario_marcaciones', 'horario_turnos_habilitados'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.horario_puede_editar(area_id) or public.es_rrhh())', t || '_ver', t);
  end loop;
end $$;
drop policy if exists horario_quincenas_cerradas_ver on public.horario_quincenas_cerradas;
create policy horario_quincenas_cerradas_ver on public.horario_quincenas_cerradas for select to authenticated
  using (public.has_area_access(area_id) or public.es_rrhh());

-- Salarios: admin del área o Recursos humanos (ver y editar)
drop policy if exists horario_salarios_ver on public.horario_salarios;
drop policy if exists horario_salarios_crear on public.horario_salarios;
drop policy if exists horario_salarios_editar on public.horario_salarios;
drop policy if exists horario_salarios_borrar on public.horario_salarios;
create policy horario_salarios_ver on public.horario_salarios for select to authenticated
  using (((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id)) or public.es_rrhh());
create policy horario_salarios_crear on public.horario_salarios for insert to authenticated
  with check (((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id)) or public.es_rrhh());
create policy horario_salarios_editar on public.horario_salarios for update to authenticated
  using (((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id)) or public.es_rrhh())
  with check (((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id)) or public.es_rrhh());
create policy horario_salarios_borrar on public.horario_salarios for delete to authenticated
  using (((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id)) or public.es_rrhh());

-- Soportes de novedades y fotos de marcación: Recursos humanos también los puede ver
create or replace function public.horario_puede_ver_soporte(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_area uuid;
begin
  begin v_area := split_part(p_nombre, '/', 1)::uuid; exception when others then return false; end;
  return public.horario_puede_editar(v_area) or public.es_rrhh();
end;
$$;

-- 2) Horarios en todas las áreas de los restaurantes (no en los puntos centrales Admin y Eventos)
update public.areas a
set modules = coalesce(a.modules, '[]'::jsonb) || '["horarios"]'::jsonb
from public.locations l
where l.id = a.location_id and coalesce(l.slug, '') not in ('admin', 'eventos')
  and not coalesce(a.modules, '[]'::jsonb) @> '["horarios"]'::jsonb;

notify pgrst, 'reload schema';

-- Debe mostrar cada punto con sus áreas y "true" en horarios
select l.name as punto, a.name as area, a.modules @> '["horarios"]'::jsonb as horarios
from public.areas a join public.locations l on l.id = a.location_id
order by 1, 2;
