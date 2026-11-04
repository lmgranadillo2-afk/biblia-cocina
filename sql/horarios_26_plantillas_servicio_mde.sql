-- Servicio de Cantina Dos Santos Medellín: Líderes, Caja, Puerta, Catrinos y Oficios varios, de las plantillas del 2 al 8 nov 2026.
-- Se agregan a la semana del 2 nov, que sigue publicada; no toca los turnos de los asesores.
-- Decisiones de Miguel: misma área con estaciones; sin descanso fijo; novedad nueva Compensatorio; Catrinos no trabajan de lunes a
-- miércoles (van como descanso) y su domingo queda sin casilla porque la plantilla no lo trae; salario fijo de los líderes por definir.
-- Basuras noche: miércoles y domingo Franco sale antes de la 1 a. m., así que esos días van "antes de salir" (Miguel: otro horario).
-- horario_tareas.fija = encargado fijo: no rota ni avisa por repetir. No borra datos; se puede correr más de una vez.
-- Correr DESPUÉS de que Vercel despliegue la app que conoce la novedad Compensatorio.
alter table public.horario_novedades drop constraint if exists horario_novedades_tipo_check;
alter table public.horario_novedades add constraint horario_novedades_tipo_check
  check (tipo in ('incapacidad', 'vacaciones', 'permiso', 'calamidad', 'compensatorio', 'vacante', 'retardo'));
alter table public.horario_tareas add column if not exists fija boolean not null default false;

do $$
declare v_area uuid; v_sem uuid; v_estado text;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'SERVICIO%' limit 1;
  if v_area is null then raise exception 'No encontré el área Servicio de Cantina Dos Santos Medellín'; end if;
  select id, estado into v_sem, v_estado from public.horario_semanas where area_id = v_area and lunes = '2026-11-02';
  if v_sem is null then raise exception 'No encontré la semana del 2 nov en Servicio'; end if;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Líderes', 1, '{0,0,0,0,0,0,0}', 2),
    (v_area, 'Caja', 7, '{0,0,0,0,0,0,0}', 3),
    (v_area, 'Puerta', 4, '{0,0,0,0,0,0,0}', 4),
    (v_area, 'Catrinos', 5, '{0,0,0,0,0,0,0}', 5),
    (v_area, 'Oficios varios', 6, '{0,0,0,0,0,0,0}', 6)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '11AM-3PM/7PM-12AM', 9, true, true, '[{"desde":"11:00","hasta":"15:00"},{"desde":"19:00","hasta":"00:00"}]'::jsonb, 17),
    (v_area, '11:30AM-6:30PM', 7, true, false, '[{"desde":"11:30","hasta":"18:30"}]'::jsonb, 18),
    (v_area, '12PM-6:30PM', 6.5, true, false, '[{"desde":"12:00","hasta":"18:30"}]'::jsonb, 19),
    (v_area, '12PM-8PM', 8, true, false, '[{"desde":"12:00","hasta":"20:00"}]'::jsonb, 20),
    (v_area, '1PM-6:30PM', 5.5, false, false, '[{"desde":"13:00","hasta":"18:30"}]'::jsonb, 21),
    (v_area, '7PM-12AM', 5, false, true, '[{"desde":"19:00","hasta":"00:00"}]'::jsonb, 22),
    (v_area, '7PM-1AM', 6, false, true, '[{"desde":"19:00","hasta":"01:00"}]'::jsonb, 23),
    (v_area, '7PM-2AM', 7, false, true, '[{"desde":"19:00","hasta":"02:00"}]'::jsonb, 24)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, orden)
  select v_area, v.nombre, e.id, v.cargo, v.orden
  from (values
    ('Arturo Tatis', 'Líderes', 'Líder', 10),
    ('Vahuer Rey', 'Líderes', 'Líder', 11),
    ('Clara Simanca', 'Caja', 'Caja', 12),
    ('Maria Lopez', 'Caja', 'Caja', 13),
    ('Santiago Restrepo', 'Puerta', 'Puerta', 14),
    ('Camila Restrepo', 'Puerta', 'Puerta', 15),
    ('Diego', 'Catrinos', 'Catrino', 16),
    ('Katherine', 'Catrinos', 'Catrino', 17),
    ('Mariana', 'Catrinos', 'Catrino', 18),
    ('Franco Saez', 'Oficios varios', 'Oficios varios', 19),
    ('Juan Vicente', 'Oficios varios', 'Oficios varios', 20)
  ) as v(nombre, estacion, cargo, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = v.estacion
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
  select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
         coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
  from (values
    ('Arturo Tatis', 1, '12PM-8PM'), ('Arturo Tatis', 2, '4PM-12AM'), ('Arturo Tatis', 3, '12PM-8PM'), ('Arturo Tatis', 4, '12PM-8PM'), ('Arturo Tatis', 5, '12PM-8PM'), ('Arturo Tatis', 6, '12PM-8PM'), ('Arturo Tatis', 7, 'DES'),
    ('Vahuer Rey', 1, '6PM-12AM'), ('Vahuer Rey', 2, 'DES'), ('Vahuer Rey', 3, '6PM-1AM'), ('Vahuer Rey', 4, '6PM-2AM'), ('Vahuer Rey', 5, '6PM-2AM'), ('Vahuer Rey', 6, '6PM-2AM'), ('Vahuer Rey', 7, '6PM-12AM'),
    ('Clara Simanca', 1, '12PM-6:30PM'), ('Clara Simanca', 2, '4PM-12AM'), ('Clara Simanca', 3, 'DES'), ('Clara Simanca', 4, '12PM-6:30PM'), ('Clara Simanca', 5, '12PM-6:30PM'), ('Clara Simanca', 6, '12PM-6:30PM'), ('Clara Simanca', 7, '1PM-6:30PM'),
    ('Maria Lopez', 1, '6:30PM-12AM'), ('Maria Lopez', 2, 'DES'), ('Maria Lopez', 3, '6:30PM-1AM'), ('Maria Lopez', 4, '6:30PM-2AM'), ('Maria Lopez', 5, '6:30PM-2AM'), ('Maria Lopez', 6, '6:30PM-2AM'), ('Maria Lopez', 7, '6:30PM-2AM'),
    ('Santiago Restrepo', 1, 'DES'), ('Santiago Restrepo', 2, '7PM-12AM'), ('Santiago Restrepo', 3, '7PM-1AM'), ('Santiago Restrepo', 4, '7PM-2AM'), ('Santiago Restrepo', 5, '7PM-2AM'), ('Santiago Restrepo', 6, '7PM-2AM'), ('Santiago Restrepo', 7, '7PM-12AM'),
    ('Camila Restrepo', 1, '6PM-12AM'), ('Camila Restrepo', 2, 'DES'), ('Camila Restrepo', 3, '6PM-12AM'), ('Camila Restrepo', 4, '6PM-12AM'), ('Camila Restrepo', 5, '6PM-12AM'), ('Camila Restrepo', 6, '6PM-12AM'), ('Camila Restrepo', 7, '6PM-12AM'),
    ('Diego', 1, 'DES'), ('Diego', 2, 'DES'), ('Diego', 3, 'DES'), ('Diego', 5, '7PM-1AM'), ('Diego', 6, '7PM-1AM'),
    ('Katherine', 1, 'DES'), ('Katherine', 2, 'DES'), ('Katherine', 3, 'DES'),
    ('Mariana', 1, 'DES'), ('Mariana', 2, 'DES'), ('Mariana', 3, 'DES'), ('Mariana', 4, '6PM-12AM'), ('Mariana', 5, '7PM-1AM'), ('Mariana', 6, '7PM-1AM'),
    ('Franco Saez', 1, '6:30PM-2AM'), ('Franco Saez', 2, 'DES'), ('Franco Saez', 3, '6:30PM-1AM'), ('Franco Saez', 4, '6:30PM-2AM'), ('Franco Saez', 5, '6:30PM-2AM'), ('Franco Saez', 6, '6:30PM-2AM'), ('Franco Saez', 7, '6:30PM-12AM'),
    ('Juan Vicente', 1, '11AM-6PM'), ('Juan Vicente', 2, '11AM-3PM/7PM-12AM'), ('Juan Vicente', 3, '11:30AM-6:30PM'), ('Juan Vicente', 4, '11AM-6:30PM'), ('Juan Vicente', 5, 'DES'), ('Juan Vicente', 6, '11AM-6:30PM'), ('Juan Vicente', 7, '11AM-6:30PM')
  ) as v(nombre, dia, cod)
  join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
  left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod
  on conflict do nothing;

  insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
  select v_area, p.id, v.tipo, v.desde::date, v.hasta::date, 'Cargado de la plantilla', 'Plantilla'
  from (values
    ('Katherine', 'vacaciones', '2026-11-05', '2026-11-07'),
    ('Diego', 'compensatorio', '2026-11-05', '2026-11-05')
  ) as v(nombre, tipo, desde, hasta)
  join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
  where not exists (select 1 from public.horario_novedades n where n.personal_id = p.id and n.tipo = v.tipo and n.desde = v.desde::date);

  insert into public.horario_tareas (area_id, nombre, detalle, orden, fija) values
    (v_area, 'Basuras tarde', '5 a 6 p. m.', 1, true),
    (v_area, 'Basuras noche', '1 a 2 a. m.; mié y dom antes de salir', 2, true)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_tarea_asignaciones (semana_id, tarea_id, dia, personal_id)
  select v_sem, t.id, v.dia, p.id
  from (values
    ('Basuras tarde', 1, 'Juan Vicente'), ('Basuras tarde', 3, 'Juan Vicente'), ('Basuras tarde', 4, 'Juan Vicente'), ('Basuras tarde', 6, 'Juan Vicente'), ('Basuras tarde', 7, 'Juan Vicente'),
    ('Basuras noche', 1, 'Franco Saez'), ('Basuras noche', 3, 'Franco Saez'), ('Basuras noche', 4, 'Franco Saez'), ('Basuras noche', 5, 'Franco Saez'), ('Basuras noche', 6, 'Franco Saez'), ('Basuras noche', 7, 'Franco Saez')
  ) as v(tarea, dia, nombre)
  join public.horario_tareas t on t.area_id = v_area and t.nombre = v.tarea
  join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
  on conflict do nothing;
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar las 11 personas nuevas con sus horas: Arturo 48, Vahuer 43, Clara 39,5, Maria 42, Santiago 37, Camila 36, Diego 12, Katherine 0, Mariana 18, Franco 42, Juan Vicente 45,5
select e.nombre estacion, p.nombre, count(x.*) casillas, coalesce(sum(x.horas), 0) horas
from public.horario_personal p
join public.horario_estaciones e on e.id = p.estacion_id
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
join public.horario_semanas s on s.area_id = a.id and s.lunes = '2026-11-02'
left join public.horario_asignaciones x on x.semana_id = s.id and x.personal_id = p.id
where l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'SERVICIO%' and p.orden >= 10
group by e.orden, e.nombre, p.orden, p.nombre order by e.orden, p.orden;
