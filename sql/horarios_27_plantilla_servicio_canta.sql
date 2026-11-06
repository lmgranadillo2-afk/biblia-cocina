-- Plantilla de Horarios para Servicio de Canta Corazón, tomada de la plantilla de Miguel (5 nov 2026).
-- Se carga en la semana del 2 al 8 nov como BORRADOR (decisión de Miguel). Crea estaciones, personal y turnos (no duplica).
-- La plantilla no trae nombre de semana ni hora de "cierre": se sacó del TOTAL de horas de cada casilla:
--   4PM-CIERRE 10 h → 2 a. m.; 5PM-CIERRE 9 h → 2 a. m.; 6PM-CIERRE (seguridad) 9 h → 3 a. m.;
--   5:30PM-CIERRE DS 5,5 h → 11 p. m.; 3PM-FINAL HAPPENINGS 9 h → 12 a. m.
-- Domingo y lunes descansa todo el equipo (ya estaba en la configuración del área). No borra datos.
do $$
declare v_area uuid; v_sem uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where l.name = 'Canta Corazon' and upper(trim(a.name)) like 'SERVICIO%' limit 1;
  if v_area is null then raise exception 'No encontré el área Servicio de Canta Corazón'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Servicio', 2, '{0,0,0,0,0,0,0}', 1), (v_area, 'Aseo', 6, '{0,0,0,0,0,0,0}', 2),
    (v_area, 'Host', 4, '{0,0,0,0,0,0,0}', 3), (v_area, 'Seguridad', 8, '{0,0,0,0,0,0,0}', 4),
    (v_area, 'Caja', 7, '{0,0,0,0,0,0,0}', 5), (v_area, 'Santo', 5, '{0,0,0,0,0,0,0}', 6)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '9AM-5PM', 8, true, false, '[{"desde":"09:00","hasta":"17:00"}]'::jsonb, 1),
    (v_area, '10AM-4PM', 6, true, false, '[{"desde":"10:00","hasta":"16:00"}]'::jsonb, 2),
    (v_area, '12PM-4PM', 4, true, false, '[{"desde":"12:00","hasta":"16:00"}]'::jsonb, 3),
    (v_area, '3PM-FINAL HAPPENINGS', 9, false, false, '[{"desde":"15:00","hasta":"00:00"}]'::jsonb, 4),
    (v_area, '4PM-CIERRE', 10, false, true, '[{"desde":"16:00","hasta":"02:00"}]'::jsonb, 5),
    (v_area, '5PM-CIERRE', 9, false, true, '[{"desde":"17:00","hasta":"02:00"}]'::jsonb, 6),
    (v_area, '5PM-1AM', 8, false, true, '[{"desde":"17:00","hasta":"01:00"}]'::jsonb, 7),
    (v_area, '5:30PM-CIERRE DS', 5.5, false, false, '[{"desde":"17:30","hasta":"23:00"}]'::jsonb, 8),
    (v_area, '6PM-CIERRE', 9, false, true, '[{"desde":"18:00","hasta":"03:00"}]'::jsonb, 9)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, orden)
  select v_area, v.nombre, e.id, v.cargo, v.orden
  from (values
    ('Jhonatan', 'Servicio', 'Mesero', 1), ('Stefany', 'Servicio', 'Mesero', 2), ('Albany', 'Servicio', 'Mesero', 3),
    ('Stiven', 'Servicio', 'Mesero', 4), ('Julian', 'Servicio', 'Mesero', 5), ('Alejandro', 'Servicio', 'Mesero', 6),
    ('Sol', 'Servicio', 'Mesero', 7), ('Lady', 'Servicio', 'Mesero', 8), ('Staly', 'Servicio', 'Mesero', 9),
    ('Nohora', 'Aseo', 'Aseo', 10), ('Violeta', 'Host', 'Host', 11), ('Jaime', 'Seguridad', 'Seguridad', 12),
    ('Grecia', 'Caja', 'Caja', 13), ('Huver', 'Santo', 'Santo', 14)
  ) as v(nombre, estacion, cargo, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = v.estacion
  on conflict (area_id, nombre) do nothing;

  if exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-11-02') then
    raise exception 'La semana del 2 nov ya existe en Servicio de Canta Corazón: no la toco';
  end if;
  insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-11-02') returning id into v_sem;

  insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
  select v_sem, p.id, d.dia, case when d.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
         coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
  from (values
    ('Jhonatan',  'DES,12PM-4PM,DES,4PM-CIERRE,5PM-CIERRE,5PM-CIERRE,DES'),
    ('Stefany',   'DES,DES,DES,4PM-CIERRE,4PM-CIERRE,4PM-CIERRE,DES'),
    ('Albany',    'DES,DES,9AM-5PM,9AM-5PM,9AM-5PM,9AM-5PM,DES'),
    ('Stiven',    'DES,DES,DES,4PM-CIERRE,4PM-CIERRE,4PM-CIERRE,DES'),
    ('Julian',    'DES,12PM-4PM,DES,4PM-CIERRE,5PM-CIERRE,5PM-CIERRE,DES'),
    ('Alejandro', 'DES,DES,DES,4PM-CIERRE,4PM-CIERRE,4PM-CIERRE,DES'),
    ('Sol',       'DES,12PM-4PM,DES,4PM-CIERRE,5PM-CIERRE,5PM-CIERRE,DES'),
    ('Lady',      'DES,12PM-4PM,DES,4PM-CIERRE,5PM-CIERRE,5PM-CIERRE,DES'),
    ('Staly',     'DES,12PM-4PM,DES,4PM-CIERRE,5PM-CIERRE,5PM-CIERRE,DES'),
    ('Nohora',    'DES,10AM-4PM,DES,4PM-CIERRE,4PM-CIERRE,4PM-CIERRE,DES'),
    ('Violeta',   'DES,DES,5:30PM-CIERRE DS,5PM-1AM,5PM-1AM,5PM-1AM,DES'),
    ('Jaime',     'DES,DES,DES,6PM-CIERRE,6PM-CIERRE,6PM-CIERRE,DES'),
    ('Grecia',    'DES,10AM-4PM,DES,4PM-CIERRE,4PM-CIERRE,4PM-CIERRE,DES'),
    ('Huver',     'DES,12PM-4PM,DES,3PM-FINAL HAPPENINGS,3PM-FINAL HAPPENINGS,3PM-FINAL HAPPENINGS,DES')
  ) as v(nombre, semana)
  cross join lateral (select ord::int as dia, cod from unnest(string_to_array(v.semana, ',')) with ordinality as u(cod, ord)) d
  join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
  left join public.horario_turnos t on t.area_id = v_area and t.codigo = d.cod;
end $$;

-- Debe mostrar 14 personas con 7 casillas cada una
select e.nombre estacion, p.nombre, count(x.*) casillas, sum(x.horas) horas
from public.horario_personal p join public.horario_estaciones e on e.id = p.estacion_id
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
join public.horario_semanas s on s.area_id = a.id and s.lunes = '2026-11-02'
left join public.horario_asignaciones x on x.semana_id = s.id and x.personal_id = p.id
where l.name = 'Canta Corazon' and upper(trim(a.name)) like 'SERVICIO%'
group by e.orden, e.nombre, p.orden, p.nombre order by e.orden, p.orden;
