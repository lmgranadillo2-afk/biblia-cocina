-- Plantilla de Horarios para Barra de Cantina Dos Santos Medellín, tomada del horario del 2 al 8 nov 2026.
-- Crea la estación Barra, el personal y los turnos (no duplica si ya existen) y carga esa semana como BORRADOR.
-- No borra datos. Desde el 2 nov rige el descanso fijo: se toma el día FREE de esta semana (se cambia en Configuración → Personal).
-- César descansa domingo: por eso "días en que solo descansa producción" queda vacío. Mínimos por día en 0 (se pueden ajustar).
do $$
declare v_area uuid; v_sem uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'BARRA%' limit 1;
  if v_area is null then raise exception 'No encontré el área Barra de Cantina Dos Santos Medellín'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;
  update public.horario_config set dias_sin_descanso = '{}' where area_id = v_area;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Barra', 3, '{0,0,0,0,0,0,0}', 1)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '10AM-5PM', 7, true, false, '[{"desde":"10:00","hasta":"17:00"}]'::jsonb, 1),
    (v_area, '11AM-6PM', 7, true, false, '[{"desde":"11:00","hasta":"18:00"}]'::jsonb, 2),
    (v_area, '4PM-11PM', 7, false, false, '[{"desde":"16:00","hasta":"23:00"}]'::jsonb, 3),
    (v_area, '5PM-12AM', 7, false, true, '[{"desde":"17:00","hasta":"00:00"}]'::jsonb, 4),
    (v_area, '6PM-1AM', 7, false, true, '[{"desde":"18:00","hasta":"01:00"}]'::jsonb, 5),
    (v_area, '7PM-2AM', 7, false, true, '[{"desde":"19:00","hasta":"02:00"}]'::jsonb, 6)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, descanso_dia, orden)
  select v_area, v.nombre, e.id, v.descanso, v.orden
  from (values
    ('Cesar', 7::smallint, 1),
    ('Nelson', 1::smallint, 2),
    ('Laura', 3::smallint, 3),
    ('Alejandro', 2::smallint, 4)
  ) as v(nombre, descanso, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = 'Barra'
  on conflict (area_id, nombre) do nothing;

  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-11-02') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-11-02') returning id into v_sem;
    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('Cesar', 1, '5PM-12AM'),
      ('Cesar', 2, '5PM-12AM'),
      ('Cesar', 3, '6PM-1AM'),
      ('Cesar', 4, '4PM-11PM'),
      ('Cesar', 5, '7PM-2AM'),
      ('Cesar', 6, '7PM-2AM'),
      ('Cesar', 7, 'DES'),
      ('Nelson', 1, 'DES'),
      ('Nelson', 2, '10AM-5PM'),
      ('Nelson', 3, '11AM-6PM'),
      ('Nelson', 4, '11AM-6PM'),
      ('Nelson', 5, '10AM-5PM'),
      ('Nelson', 6, '10AM-5PM'),
      ('Nelson', 7, '11AM-6PM'),
      ('Laura', 1, '11AM-6PM'),
      ('Laura', 2, '5PM-12AM'),
      ('Laura', 3, 'DES'),
      ('Laura', 4, '7PM-2AM'),
      ('Laura', 5, '5PM-12AM'),
      ('Laura', 6, '5PM-12AM'),
      ('Laura', 7, '5PM-12AM'),
      ('Alejandro', 1, '5PM-12AM'),
      ('Alejandro', 2, 'DES'),
      ('Alejandro', 3, '6PM-1AM'),
      ('Alejandro', 4, '7PM-2AM'),
      ('Alejandro', 5, '7PM-2AM'),
      ('Alejandro', 6, '7PM-2AM'),
      ('Alejandro', 7, '5PM-12AM')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;
  end if;
end $$;

-- Debe mostrar 4 personas con 42 h cada una y la semana del 2 nov en borrador
select p.orden, p.nombre, p.descanso_dia, s.lunes, s.estado, count(x.*) as casillas, sum(x.horas) as horas
from public.horario_personal p
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
join public.horario_semanas s on s.area_id = a.id and s.lunes = '2026-11-02'
left join public.horario_asignaciones x on x.semana_id = s.id and x.personal_id = p.id
where l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'BARRA%'
group by p.orden, p.nombre, p.descanso_dia, s.lunes, s.estado order by p.orden;
