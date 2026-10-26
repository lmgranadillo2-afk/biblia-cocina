-- Plantilla de Horarios para Servicio de Cantina Dos Santos Medellín, tomada del horario del 26 oct al 1 nov 2026.
-- Crea la estación Asesores, el personal y los turnos (no duplica si ya existen) y carga esa semana como BORRADOR.
-- No borra datos. Descanso rotativo hasta el 1 nov (como todo Medellín); desde el 2 nov rige el descanso fijo de cada persona,
-- que hay que poner en Configuración → Personal. En Servicio descansan varios el mismo día y también fines de semana:
-- por eso "días en que solo descansa producción" queda vacío y los mínimos por día en 0 (se pueden ajustar).
-- Correcciones de la imagen: 6:30PM-1PM → 6:30PM-1AM, 5:30PM-2PM → 5:30PM-2AM, 6PM-1PM → 6PM-1AM, 4:30PM-1PM → 4:30PM-1AM,
-- 3PM-11 AM → 3PM-11PM, 12AM-4PM/7PM-11p → 12PM-4PM/7PM-11PM. Viviana: vacaciones toda la semana.
do $$
declare v_area uuid; v_sem uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'SERVICIO%' limit 1;
  if v_area is null then raise exception 'No encontré el área Servicio de Cantina Dos Santos Medellín'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;
  update public.horario_config set dias_sin_descanso = '{}', descanso_todos = '{}', descanso_rotativo_desde = null, descanso_rotativo_hasta = '2026-11-01'
  where area_id = v_area;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Asesores', 2, '{0,0,0,0,0,0,0}', 1)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '9AM-4PM', 7, true, false, '[{"desde":"09:00","hasta":"16:00"}]'::jsonb, 1),
    (v_area, '11AM-6PM', 7, true, false, '[{"desde":"11:00","hasta":"18:00"}]'::jsonb, 2),
    (v_area, '11AM-6:30PM', 7.5, true, false, '[{"desde":"11:00","hasta":"18:30"}]'::jsonb, 3),
    (v_area, '12PM-4PM/7PM-11PM', 8, true, false, '[{"desde":"12:00","hasta":"16:00"},{"desde":"19:00","hasta":"23:00"}]'::jsonb, 4),
    (v_area, '1PM-4:30PM/7PM-11PM', 7.5, false, false, '[{"desde":"13:00","hasta":"16:30"},{"desde":"19:00","hasta":"23:00"}]'::jsonb, 5),
    (v_area, '3PM-11PM', 8, false, false, '[{"desde":"15:00","hasta":"23:00"}]'::jsonb, 6),
    (v_area, '4PM-12AM', 8, false, true, '[{"desde":"16:00","hasta":"00:00"}]'::jsonb, 7),
    (v_area, '4:30PM-1AM', 8.5, false, true, '[{"desde":"16:30","hasta":"01:00"}]'::jsonb, 8),
    (v_area, '5:30PM-1AM', 7.5, false, true, '[{"desde":"17:30","hasta":"01:00"}]'::jsonb, 9),
    (v_area, '5:30PM-2AM', 8.5, false, true, '[{"desde":"17:30","hasta":"02:00"}]'::jsonb, 10),
    (v_area, '6PM-12AM', 6, false, true, '[{"desde":"18:00","hasta":"00:00"}]'::jsonb, 11),
    (v_area, '6PM-1AM', 7, false, true, '[{"desde":"18:00","hasta":"01:00"}]'::jsonb, 12),
    (v_area, '6PM-2AM', 8, false, true, '[{"desde":"18:00","hasta":"02:00"}]'::jsonb, 13),
    (v_area, '6:30PM-12AM', 5.5, false, true, '[{"desde":"18:30","hasta":"00:00"}]'::jsonb, 14),
    (v_area, '6:30PM-1AM', 6.5, false, true, '[{"desde":"18:30","hasta":"01:00"}]'::jsonb, 15),
    (v_area, '6:30PM-2AM', 7.5, false, true, '[{"desde":"18:30","hasta":"02:00"}]'::jsonb, 16)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, orden)
  select v_area, v.nombre, e.id, 'Asesor', v.orden
  from (values
    ('Viviana Arguello', 1),
    ('Yonder Patiño', 2),
    ('Aaron Agudelo', 3),
    ('Sebastian Cartagena', 4),
    ('Grabiel Lopez', 5),
    ('Erick Revilla', 6),
    ('Cristian Calvo', 7),
    ('Samer Riveros', 8),
    ('Juan Martinez', 9)
  ) as v(nombre, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = 'Asesores'
  on conflict (area_id, nombre) do nothing;

  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-10-26') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-10-26') returning id into v_sem;
    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('Yonder Patiño', 1, 'DES'),
      ('Yonder Patiño', 2, '6:30PM-12AM'),
      ('Yonder Patiño', 3, '11AM-6:30PM'),
      ('Yonder Patiño', 4, '6PM-2AM'),
      ('Yonder Patiño', 5, '1PM-4:30PM/7PM-11PM'),
      ('Yonder Patiño', 6, '6:30PM-2AM'),
      ('Yonder Patiño', 7, '6PM-12AM'),
      ('Aaron Agudelo', 1, '6PM-12AM'),
      ('Aaron Agudelo', 2, 'DES'),
      ('Aaron Agudelo', 3, '6PM-1AM'),
      ('Aaron Agudelo', 4, '4:30PM-1AM'),
      ('Aaron Agudelo', 5, '6:30PM-2AM'),
      ('Aaron Agudelo', 6, '6PM-2AM'),
      ('Aaron Agudelo', 7, '1PM-4:30PM/7PM-11PM'),
      ('Sebastian Cartagena', 1, '9AM-4PM'),
      ('Sebastian Cartagena', 2, '6PM-12AM'),
      ('Sebastian Cartagena', 3, '6:30PM-1AM'),
      ('Sebastian Cartagena', 4, '1PM-4:30PM/7PM-11PM'),
      ('Sebastian Cartagena', 5, '6PM-2AM'),
      ('Sebastian Cartagena', 6, '4:30PM-1AM'),
      ('Sebastian Cartagena', 7, 'DES'),
      ('Grabiel Lopez', 1, '6PM-12AM'),
      ('Grabiel Lopez', 2, 'DES'),
      ('Grabiel Lopez', 3, '6:30PM-1AM'),
      ('Grabiel Lopez', 4, '6:30PM-1AM'),
      ('Grabiel Lopez', 5, '4:30PM-1AM'),
      ('Grabiel Lopez', 6, '5:30PM-2AM'),
      ('Grabiel Lopez', 7, '6PM-12AM'),
      ('Erick Revilla', 1, '4PM-12AM'),
      ('Erick Revilla', 2, '3PM-11PM'),
      ('Erick Revilla', 3, 'DES'),
      ('Erick Revilla', 4, '6PM-2AM'),
      ('Erick Revilla', 5, '11AM-6PM'),
      ('Erick Revilla', 6, '11AM-6PM'),
      ('Erick Revilla', 7, '11AM-6PM'),
      ('Cristian Calvo', 1, 'DES'),
      ('Cristian Calvo', 2, '6:30PM-12AM'),
      ('Cristian Calvo', 3, '6PM-1AM'),
      ('Cristian Calvo', 4, '5:30PM-2AM'),
      ('Cristian Calvo', 5, '4:30PM-1AM'),
      ('Cristian Calvo', 6, '1PM-4:30PM/7PM-11PM'),
      ('Cristian Calvo', 7, '6PM-12AM'),
      ('Samer Riveros', 1, '6PM-12AM'),
      ('Samer Riveros', 2, '6:30PM-12AM'),
      ('Samer Riveros', 3, '12PM-4PM/7PM-11PM'),
      ('Samer Riveros', 4, '4:30PM-1AM'),
      ('Samer Riveros', 5, '6PM-2AM'),
      ('Samer Riveros', 6, '6PM-1AM'),
      ('Samer Riveros', 7, 'DES'),
      ('Juan Martinez', 1, '9AM-4PM'),
      ('Juan Martinez', 2, 'DES'),
      ('Juan Martinez', 3, '6:30PM-1AM'),
      ('Juan Martinez', 4, '11AM-6PM'),
      ('Juan Martinez', 5, '5:30PM-1AM'),
      ('Juan Martinez', 6, '4:30PM-1AM'),
      ('Juan Martinez', 7, '6PM-12AM')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;

    insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
    select v_area, p.id, 'vacaciones', '2026-10-26', '2026-11-01', 'Cargado de la plantilla', 'Plantilla'
    from public.horario_personal p where p.area_id = v_area and p.nombre = 'Viviana Arguello';
  end if;
end $$;

-- Debe mostrar 9 asesores y la semana del 26 oct en borrador con 56 casillas
select p.orden, p.nombre, p.cargo from public.horario_personal p
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
where l.slug = 'dos-santos' and upper(trim(a.name)) like 'SERVICIO%' order by p.orden;
select s.lunes, s.estado, count(x.*) as casillas
from public.horario_semanas s join public.areas a on a.id = s.area_id join public.locations l on l.id = a.location_id
left join public.horario_asignaciones x on x.semana_id = s.id
where l.slug = 'dos-santos' and upper(trim(a.name)) like 'SERVICIO%' group by s.lunes, s.estado;
