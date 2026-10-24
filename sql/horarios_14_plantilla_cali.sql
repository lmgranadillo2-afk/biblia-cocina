-- Plantilla de Horarios para Cocina de Dos Santos Cali, tomada del horario de la semana del 26 oct al 1 nov 2026.
-- Crea estaciones, personal, turnos y tareas (no duplica si ya existen) y carga esa semana como BORRADOR para revisar y
-- publicar. Desde ahí, "Proponer semana" copia los turnos de la semana anterior. No borra datos.
--
-- En Cali no descansa todo el equipo el lunes: Mariana (líder) descansa el martes y Alfreth (producción) el domingo,
-- así que en Cocina Cali queda el descanso fijo de cada persona (los demás el lunes). Enrique: vacaciones toda la semana.
do $$
declare v_area uuid; v_sem uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where l.slug = 'dos-santos-cali-mtg0p7fs' and upper(trim(a.name)) like 'COCINA%' limit 1;
  if v_area is null then raise exception 'No encontré el área Cocina de Dos Santos Cali'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;
  update public.horario_config set descanso_todos = '{}', descanso_rotativo_desde = null, descanso_rotativo_hasta = null where area_id = v_area;

  -- Estaciones y mínimos por día (lunes a domingo)
  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Líder', 1, '{1,1,1,1,1,1,1}', 1),
    (v_area, 'Fría', 3, '{0,1,1,1,1,1,1}', 2),
    (v_area, 'Parrilla', 4, '{0,1,1,1,1,1,1}', 3),
    (v_area, 'Producción', 5, '{1,1,1,1,1,1,0}', 4),
    (v_area, 'Tacos', 6, '{0,1,1,1,1,1,1}', 5),
    (v_area, 'Steward', 7, '{0,1,1,1,1,1,1}', 6)
  on conflict (area_id, nombre) do nothing;

  -- Turnos (C = cierra)
  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '6-1', 7, true, false, '[{"desde":"06:00","hasta":"13:00"}]'::jsonb, 1),
    (v_area, '8-1', 5, true, false, '[{"desde":"08:00","hasta":"13:00"}]'::jsonb, 2),
    (v_area, '8-2', 6, true, false, '[{"desde":"08:00","hasta":"14:00"}]'::jsonb, 3),
    (v_area, '8-3', 7, true, false, '[{"desde":"08:00","hasta":"15:00"}]'::jsonb, 4),
    (v_area, '8-4', 8, true, false, '[{"desde":"08:00","hasta":"16:00"}]'::jsonb, 5),
    (v_area, '11-5', 6, true, false, '[{"desde":"11:00","hasta":"17:00"}]'::jsonb, 6),
    (v_area, '3-9', 6, false, false, '[{"desde":"15:00","hasta":"21:00"}]'::jsonb, 7),
    (v_area, '4-12 C', 8, false, true, '[{"desde":"16:00","hasta":"00:00"}]'::jsonb, 8),
    (v_area, '5-12 C', 7, false, true, '[{"desde":"17:00","hasta":"00:00"}]'::jsonb, 9),
    (v_area, '6-12 C', 6, false, true, '[{"desde":"18:00","hasta":"00:00"}]'::jsonb, 10),
    (v_area, '5-1 C', 8, false, true, '[{"desde":"17:00","hasta":"01:00"}]'::jsonb, 11),
    (v_area, '6-1 C', 7, false, true, '[{"desde":"18:00","hasta":"01:00"}]'::jsonb, 12),
    (v_area, '8-12 Y 7-12 C', 9, true, true, '[{"desde":"08:00","hasta":"12:00"},{"desde":"19:00","hasta":"00:00"}]'::jsonb, 13),
    (v_area, '11-5 Y 7-10', 9, true, false, '[{"desde":"11:00","hasta":"17:00"},{"desde":"19:00","hasta":"22:00"}]'::jsonb, 14),
    (v_area, '11-5 Y 8-12', 10, true, true, '[{"desde":"11:00","hasta":"17:00"},{"desde":"20:00","hasta":"00:00"}]'::jsonb, 15)
  on conflict (area_id, codigo) do nothing;

  -- Personal (descanso: 1 = lunes … 7 = domingo)
  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, descanso_dia, es_produccion, orden)
  select v_area, v.nombre, e.id, v.cargo, v.descanso, v.prod, v.orden
  from (values
    ('Mariana García', 'Líder', 'Líder', 2::smallint, false, 1),
    ('Sebastián Pietro', 'Líder', 'Líder segundo', 1::smallint, false, 2),
    ('Daniel Petrilly', 'Fría', 'Fría', 1::smallint, false, 3),
    ('Joan Enríquez', 'Parrilla', 'Parrilla', 1::smallint, false, 4),
    ('Eduardo García', 'Parrilla', 'Parrilla', 1::smallint, false, 5),
    ('Alfreth López', 'Producción', 'Producción', 7::smallint, true, 6),
    ('Enrique Loaiza Perea', 'Producción', 'Producción', null::smallint, true, 7),
    ('Wilmer Valencia', 'Tacos', 'Tacos', 1::smallint, false, 8),
    ('Andrés Gutiérrez', 'Steward', 'Steward', 1::smallint, false, 9)
  ) as v(nombre, estacion, cargo, descanso, prod, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = v.estacion
  on conflict (area_id, nombre) do nothing;

  -- Líder y líder segundo van en la misma estación (Líder); se distinguen por el cargo y cada uno tiene su salario.
  -- (Si ya se había corrido la versión anterior, esto los corrige.)
  update public.horario_personal p set estacion_id = e.id, cargo = 'Líder segundo'
  from public.horario_estaciones e where e.area_id = v_area and e.nombre = 'Líder'
    and p.area_id = v_area and p.nombre = 'Sebastián Pietro';
  update public.horario_personal set cargo = 'Líder' where area_id = v_area and nombre = 'Mariana García' and cargo is null;
  update public.horario_estaciones set minimo_por_dia = '{1,1,1,1,1,1,1}' where area_id = v_area and nombre = 'Líder';
  update public.horario_estaciones set activa = false where area_id = v_area and nombre = 'Líder segundo';

  -- Tareas
  insert into public.horario_tareas (area_id, nombre, orden) values
    (v_area, 'Aseo zonas comunes', 1),
    (v_area, 'Limpieza general', 2)
  on conflict (area_id, nombre) do nothing;

  -- Semana del 26 de octubre como borrador (solo si no existe)
  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-10-26') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-10-26') returning id into v_sem;

    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('Mariana García', 1, '8-3'),
      ('Mariana García', 2, 'DES'),
      ('Mariana García', 3, '5-12 C'),
      ('Mariana García', 4, '5-12 C'),
      ('Mariana García', 5, '5-12 C'),
      ('Mariana García', 6, '8-12 Y 7-12 C'),
      ('Mariana García', 7, '11-5'),
      ('Sebastián Pietro', 1, 'DES'),
      ('Sebastián Pietro', 2, '6-12 C'),
      ('Sebastián Pietro', 3, '8-2'),
      ('Sebastián Pietro', 4, '5-12 C'),
      ('Sebastián Pietro', 5, '4-12 C'),
      ('Sebastián Pietro', 6, '4-12 C'),
      ('Sebastián Pietro', 7, '5-12 C'),
      ('Daniel Petrilly', 1, 'DES'),
      ('Daniel Petrilly', 2, '3-9'),
      ('Daniel Petrilly', 3, '6-12 C'),
      ('Daniel Petrilly', 4, '5-12 C'),
      ('Daniel Petrilly', 5, '4-12 C'),
      ('Daniel Petrilly', 6, '4-12 C'),
      ('Daniel Petrilly', 7, '5-12 C'),
      ('Joan Enríquez', 1, 'DES'),
      ('Joan Enríquez', 2, '5-12 C'),
      ('Joan Enríquez', 3, '3-9'),
      ('Joan Enríquez', 4, '5-12 C'),
      ('Joan Enríquez', 5, '5-12 C'),
      ('Joan Enríquez', 6, '5-12 C'),
      ('Joan Enríquez', 7, '11-5 Y 7-10'),
      ('Eduardo García', 1, 'DES'),
      ('Eduardo García', 2, '8-2'),
      ('Eduardo García', 3, '6-12 C'),
      ('Eduardo García', 4, '5-12 C'),
      ('Eduardo García', 5, '4-12 C'),
      ('Eduardo García', 6, '4-12 C'),
      ('Eduardo García', 7, '5-12 C'),
      ('Alfreth López', 1, '8-1'),
      ('Alfreth López', 2, '8-4'),
      ('Alfreth López', 3, '8-4'),
      ('Alfreth López', 4, '8-4'),
      ('Alfreth López', 5, '8-3'),
      ('Alfreth López', 6, '8-2'),
      ('Alfreth López', 7, 'DES'),
      ('Wilmer Valencia', 1, 'DES'),
      ('Wilmer Valencia', 2, '5-12 C'),
      ('Wilmer Valencia', 3, '5-12 C'),
      ('Wilmer Valencia', 4, '5-12 C'),
      ('Wilmer Valencia', 5, '5-12 C'),
      ('Wilmer Valencia', 6, '5-12 C'),
      ('Wilmer Valencia', 7, '11-5 Y 8-12'),
      ('Andrés Gutiérrez', 1, 'DES'),
      ('Andrés Gutiérrez', 2, '6-12 C'),
      ('Andrés Gutiérrez', 3, '5-12 C'),
      ('Andrés Gutiérrez', 4, '6-1'),
      ('Andrés Gutiérrez', 5, '6-1 C'),
      ('Andrés Gutiérrez', 6, '5-1 C'),
      ('Andrés Gutiérrez', 7, '5-12 C')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;

    insert into public.horario_tarea_asignaciones (semana_id, tarea_id, dia, personal_id)
    select v_sem, t.id, v.dia, p.id
    from (values
      ('Aseo zonas comunes', 2, 'Andrés Gutiérrez'),
      ('Aseo zonas comunes', 5, 'Wilmer Valencia'),
      ('Limpieza general', 2, 'Eduardo García'),
      ('Limpieza general', 3, 'Sebastián Pietro')
    ) as v(tarea, dia, nombre)
    join public.horario_tareas t on t.area_id = v_area and t.nombre = v.tarea
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre;

    insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
    select v_area, p.id, 'vacaciones', '2026-10-26', '2026-11-01', 'Cargado de la plantilla', 'Plantilla'
    from public.horario_personal p where p.area_id = v_area and p.nombre = 'Enrique Loaiza Perea';
  end if;
end $$;

-- Debe mostrar 9 personas con su estación y descanso, y la semana del 26 oct en borrador con 56 casillas
select p.orden, p.nombre, e.nombre as estacion, p.descanso_dia, p.es_produccion
from public.horario_personal p left join public.horario_estaciones e on e.id = p.estacion_id
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
where l.slug = 'dos-santos-cali-mtg0p7fs' order by p.orden;
select s.lunes, s.estado, count(x.*) as casillas
from public.horario_semanas s join public.areas a on a.id = s.area_id join public.locations l on l.id = a.location_id
left join public.horario_asignaciones x on x.semana_id = s.id
where l.slug = 'dos-santos-cali-mtg0p7fs' group by s.lunes, s.estado;
