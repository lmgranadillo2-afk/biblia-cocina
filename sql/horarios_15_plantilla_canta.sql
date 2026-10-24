-- Plantilla de Horarios para Cocina de Canta Corazón, tomada del horario que mandó Miguel (24 oct 2026).
-- Crea estaciones, personal y turnos (no duplica si ya existen) y carga ese horario en la semana del 26 oct como BORRADOR,
-- para que "Proponer semana" lo copie de ahí en adelante. No borra datos.
-- Lunes y domingo descansa todo el equipo (horario_config.descanso_todos = {7,1}). Steward queda sin persona (vacante).
-- Héctor es el líder: si ya tiene usuario con acceso a esta área, queda como "Líder de horarios" y enlazado a su fila.
do $$
declare v_area uuid; v_sem uuid; v_user uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where lower(l.name) like '%canta%' and upper(trim(a.name)) like 'COCINA%' limit 1;
  if v_area is null then raise exception 'No encontré el área Cocina de Canta Corazón'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;
  update public.horario_config set descanso_todos = '{7,1}', descanso_rotativo_desde = null, descanso_rotativo_hasta = null where area_id = v_area;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Líder', 1, '{0,1,1,1,1,1,0}', 1),
    (v_area, 'Auxiliar', 2, '{0,1,1,1,1,1,0}', 2),
    (v_area, 'Steward', 7, '{0,0,0,0,0,0,0}', 3)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '9-3', 6, true, false, '[{"desde":"09:00","hasta":"15:00"}]'::jsonb, 1),
    (v_area, '9-4', 7, true, false, '[{"desde":"09:00","hasta":"16:00"}]'::jsonb, 2),
    (v_area, '11-5', 6, true, false, '[{"desde":"11:00","hasta":"17:00"}]'::jsonb, 3),
    (v_area, '3-11:45 C', 8.75, false, true, '[{"desde":"15:00","hasta":"23:45"}]'::jsonb, 4),
    (v_area, '3-12 C', 9, false, true, '[{"desde":"15:00","hasta":"00:00"}]'::jsonb, 5),
    (v_area, '4-12 C', 8, false, true, '[{"desde":"16:00","hasta":"00:00"}]'::jsonb, 6),
    (v_area, '5-12 C', 7, false, true, '[{"desde":"17:00","hasta":"00:00"}]'::jsonb, 7)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, orden)
  select v_area, v.nombre, e.id, v.cargo, v.orden
  from (values
    ('Héctor', 'Líder', 'Líder', 1),
    ('Edgar', 'Auxiliar', 'Auxiliar', 2),
    ('José', 'Auxiliar', 'Auxiliar', 3)
  ) as v(nombre, estacion, cargo, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = v.estacion
  on conflict (area_id, nombre) do nothing;

  -- Héctor: líder de horarios si ya tiene usuario en esta área
  select ua.user_id into v_user from public.user_areas ua join public.profiles pr on pr.id = ua.user_id
  where ua.area_id = v_area and translate(lower(pr.name), 'é', 'e') like 'hector%' limit 1;
  if v_user is not null then
    update public.user_areas set lider_horarios = true where area_id = v_area and user_id = v_user;
    update public.horario_personal set user_id = v_user where area_id = v_area and nombre = 'Héctor' and user_id is null;
  end if;

  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-10-26') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-10-26') returning id into v_sem;
    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('Héctor', 1, 'DES'),
      ('Héctor', 2, '9-3'),
      ('Héctor', 3, '3-11:45 C'),
      ('Héctor', 4, '4-12 C'),
      ('Héctor', 5, '3-12 C'),
      ('Héctor', 6, '5-12 C'),
      ('Héctor', 7, 'DES'),
      ('Edgar', 1, 'DES'),
      ('Edgar', 2, '11-5'),
      ('Edgar', 3, '3-11:45 C'),
      ('Edgar', 4, '4-12 C'),
      ('Edgar', 5, '3-12 C'),
      ('Edgar', 6, '5-12 C'),
      ('Edgar', 7, 'DES'),
      ('José', 1, 'DES'),
      ('José', 2, '11-5'),
      ('José', 3, '9-4'),
      ('José', 4, '5-12 C'),
      ('José', 5, '3-12 C'),
      ('José', 6, '5-12 C'),
      ('José', 7, 'DES')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;
  end if;
end $$;

-- Debe mostrar Héctor, Edgar y José; la semana del 26 oct en borrador con 21 casillas; y si Héctor quedó como líder de horarios
select p.orden, p.nombre, e.nombre as estacion, p.cargo, p.user_id is not null as tiene_usuario
from public.horario_personal p left join public.horario_estaciones e on e.id = p.estacion_id
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
where lower(l.name) like '%canta%' order by p.orden;
select s.lunes, s.estado, count(x.*) as casillas
from public.horario_semanas s join public.areas a on a.id = s.area_id join public.locations l on l.id = a.location_id
left join public.horario_asignaciones x on x.semana_id = s.id
where lower(l.name) like '%canta%' group by s.lunes, s.estado;
select pr.name, ua.lider_horarios from public.user_areas ua join public.profiles pr on pr.id = ua.user_id
join public.areas a on a.id = ua.area_id join public.locations l on l.id = a.location_id
where lower(l.name) like '%canta%' and upper(trim(a.name)) like 'COCINA%';
