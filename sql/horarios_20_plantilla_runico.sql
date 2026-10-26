-- Plantilla de Horarios para Cocina de Rúnico, tomada de los horarios del 19–25 oct y 26 oct–1 nov 2026.
-- Crea estaciones, personal y turnos (no duplica si ya existen) y carga las dos semanas como BORRADOR. No borra datos.
-- Notación de Rúnico: "4.11" = 4 p. m. a 11 p. m.; "11.4-7.10" = 11 a. m. a 4 p. m. y 7 a 10 p. m.
-- Descanso rotativo por ahora (desde el 19 oct, sin fecha de fin; cuando quede fijo se pone la fecha "hasta" en Configuración).
-- Daniel Torres: vacaciones del 20 oct al 2 nov. Amir: sábado 31 y domingo 1 sin turno (XX en la imagen).
do $$
declare v_area uuid; v_sem uuid;
begin
  select a.id into v_area from public.areas a join public.locations l on l.id = a.location_id
  where translate(lower(l.name), 'ú', 'u') like '%runico%' and upper(trim(a.name)) like 'COCINA%' limit 1;
  if v_area is null then raise exception 'No encontré el área Cocina de Rúnico'; end if;

  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;
  update public.horario_config set dias_sin_descanso = '{}', descanso_todos = '{}', descanso_rotativo_desde = '2026-10-19', descanso_rotativo_hasta = null
  where area_id = v_area;

  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Pase', 1, '{1,1,1,1,1,1,1}', 1),
    (v_area, 'Caliente', 3, '{1,1,1,1,1,1,1}', 2),
    (v_area, 'Fría', 4, '{1,1,1,1,1,1,1}', 3),
    (v_area, 'Pastelería', 5, '{1,1,1,1,1,1,1}', 4),
    (v_area, 'Producción', 6, '{1,1,1,1,1,1,0}', 5),
    (v_area, 'Steward', 7, '{1,1,1,1,1,1,1}', 6)
  on conflict (area_id, nombre) do nothing;

  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, tramos, orden) values
    (v_area, '7.3', 8, true, false, '[{"desde":"07:00","hasta":"15:00"}]'::jsonb, 1),
    (v_area, '8.2', 6, true, false, '[{"desde":"08:00","hasta":"14:00"}]'::jsonb, 2),
    (v_area, '9.3', 6, true, false, '[{"desde":"09:00","hasta":"15:00"}]'::jsonb, 3),
    (v_area, '9.4', 7, true, false, '[{"desde":"09:00","hasta":"16:00"}]'::jsonb, 4),
    (v_area, '10.5', 7, true, false, '[{"desde":"10:00","hasta":"17:00"}]'::jsonb, 5),
    (v_area, '3.10', 7, false, false, '[{"desde":"15:00","hasta":"22:00"}]'::jsonb, 6),
    (v_area, '4.10', 6, false, false, '[{"desde":"16:00","hasta":"22:00"}]'::jsonb, 7),
    (v_area, '4.11', 7, false, true, '[{"desde":"16:00","hasta":"23:00"}]'::jsonb, 8),
    (v_area, '4.12', 8, false, true, '[{"desde":"16:00","hasta":"00:00"}]'::jsonb, 9),
    (v_area, '5.12', 7, false, true, '[{"desde":"17:00","hasta":"00:00"}]'::jsonb, 10),
    (v_area, '11.3-7.9', 6, true, false, '[{"desde":"11:00","hasta":"15:00"},{"desde":"19:00","hasta":"21:00"}]'::jsonb, 11),
    (v_area, '11.3-7.10', 7, true, false, '[{"desde":"11:00","hasta":"15:00"},{"desde":"19:00","hasta":"22:00"}]'::jsonb, 12),
    (v_area, '11.4-7.10', 8, true, false, '[{"desde":"11:00","hasta":"16:00"},{"desde":"19:00","hasta":"22:00"}]'::jsonb, 13),
    (v_area, '11.4-7.11', 9, true, true, '[{"desde":"11:00","hasta":"16:00"},{"desde":"19:00","hasta":"23:00"}]'::jsonb, 14),
    (v_area, '11.4-7.12', 10, true, true, '[{"desde":"11:00","hasta":"16:00"},{"desde":"19:00","hasta":"00:00"}]'::jsonb, 15),
    (v_area, '7.12-7.12', 10, true, true, '[{"desde":"07:00","hasta":"12:00"},{"desde":"19:00","hasta":"00:00"}]'::jsonb, 16)
  on conflict (area_id, codigo) do nothing;

  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, es_produccion, orden)
  select v_area, v.nombre, e.id, v.estacion, v.prod, v.orden
  from (values
    ('David Jaramillo', 'Pase', false, 1),
    ('Claudia Taborda', 'Pase', false, 2),
    ('Daniel Berbesi', 'Caliente', false, 3),
    ('Daniel Torres', 'Caliente', false, 4),
    ('Andrés Díaz', 'Caliente', false, 5),
    ('Juan Pablo Vélez', 'Fría', false, 6),
    ('Jarrison Corrales', 'Fría', false, 7),
    ('Pablo Moreno', 'Fría', false, 8),
    ('Jesús Polanco', 'Pastelería', false, 9),
    ('Carolina Medina', 'Pastelería', false, 10),
    ('Amir Salazar', 'Producción', true, 11),
    ('Cristina Zapata', 'Steward', false, 12),
    ('Gleydis Díaz', 'Steward', false, 13)
  ) as v(nombre, estacion, prod, orden)
  join public.horario_estaciones e on e.area_id = v_area and e.nombre = v.estacion
  on conflict (area_id, nombre) do nothing;

  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-10-19') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-10-19') returning id into v_sem;
    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('David Jaramillo', 1, '8.2'),
      ('David Jaramillo', 2, '9.4'),
      ('David Jaramillo', 3, '9.4'),
      ('David Jaramillo', 4, '9.4'),
      ('David Jaramillo', 5, '3.10'),
      ('David Jaramillo', 6, '5.12'),
      ('David Jaramillo', 7, 'DES'),
      ('Claudia Taborda', 1, '4.11'),
      ('Claudia Taborda', 2, '4.11'),
      ('Claudia Taborda', 3, 'DES'),
      ('Claudia Taborda', 4, '4.11'),
      ('Claudia Taborda', 5, '5.12'),
      ('Claudia Taborda', 6, '11.4-7.10'),
      ('Claudia Taborda', 7, '11.3-7.9'),
      ('Daniel Berbesi', 1, '4.11'),
      ('Daniel Berbesi', 2, 'DES'),
      ('Daniel Berbesi', 3, '4.11'),
      ('Daniel Berbesi', 4, '11.4-7.11'),
      ('Daniel Berbesi', 5, '4.12'),
      ('Daniel Berbesi', 6, '4.12'),
      ('Daniel Berbesi', 7, '11.3-7.10'),
      ('Daniel Torres', 1, 'DES'),
      ('Andrés Díaz', 1, '4.11'),
      ('Andrés Díaz', 2, '4.11'),
      ('Andrés Díaz', 3, '11.4-7.11'),
      ('Andrés Díaz', 4, '4.11'),
      ('Andrés Díaz', 5, '11.4-7.12'),
      ('Andrés Díaz', 6, '9.4'),
      ('Andrés Díaz', 7, 'DES'),
      ('Juan Pablo Vélez', 1, '8.2'),
      ('Juan Pablo Vélez', 2, '9.4'),
      ('Juan Pablo Vélez', 3, '4.11'),
      ('Juan Pablo Vélez', 4, 'DES'),
      ('Juan Pablo Vélez', 5, '9.4'),
      ('Juan Pablo Vélez', 6, '4.11'),
      ('Juan Pablo Vélez', 7, '3.10'),
      ('Jarrison Corrales', 1, 'DES'),
      ('Jarrison Corrales', 2, '9.4'),
      ('Jarrison Corrales', 3, '4.11'),
      ('Jarrison Corrales', 4, '4.11'),
      ('Jarrison Corrales', 5, '11.4-7.10'),
      ('Jarrison Corrales', 6, '4.12'),
      ('Jarrison Corrales', 7, '11.3-7.10'),
      ('Pablo Moreno', 1, '4.11'),
      ('Pablo Moreno', 2, '4.11'),
      ('Pablo Moreno', 3, '9.4'),
      ('Pablo Moreno', 4, '11.4-7.10'),
      ('Pablo Moreno', 5, '4.12'),
      ('Pablo Moreno', 6, '11.4-7.10'),
      ('Pablo Moreno', 7, 'DES'),
      ('Jesús Polanco', 1, '8.2'),
      ('Jesús Polanco', 2, '4.11'),
      ('Jesús Polanco', 3, 'DES'),
      ('Jesús Polanco', 4, '11.4-7.11'),
      ('Jesús Polanco', 5, '11.4-7.10'),
      ('Jesús Polanco', 6, '11.4-7.10'),
      ('Jesús Polanco', 7, '3.10'),
      ('Carolina Medina', 1, '4.11'),
      ('Carolina Medina', 2, '4.11'),
      ('Carolina Medina', 3, '11.4-7.11'),
      ('Carolina Medina', 4, 'DES'),
      ('Carolina Medina', 5, '5.12'),
      ('Carolina Medina', 6, '5.12'),
      ('Carolina Medina', 7, '11.4-7.10'),
      ('Amir Salazar', 1, '8.2'),
      ('Amir Salazar', 2, '7.3'),
      ('Amir Salazar', 3, '7.3'),
      ('Amir Salazar', 4, '7.3'),
      ('Amir Salazar', 5, '7.3'),
      ('Amir Salazar', 6, '7.3'),
      ('Amir Salazar', 7, 'DES'),
      ('Cristina Zapata', 1, '8.2'),
      ('Cristina Zapata', 2, 'DES'),
      ('Cristina Zapata', 3, '4.11'),
      ('Cristina Zapata', 4, '4.11'),
      ('Cristina Zapata', 5, '5.12'),
      ('Cristina Zapata', 6, '5.12'),
      ('Cristina Zapata', 7, '11.4-7.10'),
      ('Gleydis Díaz', 1, '4.11'),
      ('Gleydis Díaz', 2, '11.4-7.11'),
      ('Gleydis Díaz', 3, '9.4'),
      ('Gleydis Díaz', 4, '9.4'),
      ('Gleydis Díaz', 5, '10.5'),
      ('Gleydis Díaz', 6, '10.5'),
      ('Gleydis Díaz', 7, 'DES')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;
  end if;

  if not exists (select 1 from public.horario_semanas where area_id = v_area and lunes = '2026-10-26') then
    insert into public.horario_semanas (area_id, lunes) values (v_area, '2026-10-26') returning id into v_sem;
    insert into public.horario_asignaciones (semana_id, personal_id, dia, tipo, turno_id, codigo, horas, cubre_manana, cubre_cierre, tramos)
    select v_sem, p.id, v.dia, case when v.cod = 'DES' then 'descanso' else 'turno' end, t.id, t.codigo, coalesce(t.horas, 0),
           coalesce(t.cubre_manana, false), coalesce(t.cubre_cierre, false), coalesce(t.tramos, '[]'::jsonb)
    from (values
      ('David Jaramillo', 1, '8.2'),
      ('David Jaramillo', 2, '9.4'),
      ('David Jaramillo', 3, '9.4'),
      ('David Jaramillo', 4, '4.11'),
      ('David Jaramillo', 5, '4.10'),
      ('David Jaramillo', 6, '7.12-7.12'),
      ('David Jaramillo', 7, '9.3'),
      ('Claudia Taborda', 1, '4.11'),
      ('Claudia Taborda', 2, '4.11'),
      ('Claudia Taborda', 3, 'DES'),
      ('Claudia Taborda', 4, '9.4'),
      ('Claudia Taborda', 5, '9.4'),
      ('Claudia Taborda', 6, '3.10'),
      ('Claudia Taborda', 7, '5.12'),
      ('Daniel Berbesi', 1, '4.11'),
      ('Daniel Berbesi', 2, '4.11'),
      ('Daniel Berbesi', 3, '11.4-7.11'),
      ('Daniel Berbesi', 4, '4.11'),
      ('Daniel Berbesi', 5, '11.4-7.10'),
      ('Daniel Berbesi', 6, '11.4-7.12'),
      ('Daniel Berbesi', 7, '9.4'),
      ('Andrés Díaz', 1, '4.11'),
      ('Andrés Díaz', 2, 'DES'),
      ('Andrés Díaz', 3, '4.11'),
      ('Andrés Díaz', 4, '11.4-7.11'),
      ('Andrés Díaz', 5, '4.12'),
      ('Andrés Díaz', 6, '4.12'),
      ('Andrés Díaz', 7, '4.12'),
      ('Juan Pablo Vélez', 1, '8.2'),
      ('Juan Pablo Vélez', 2, '9.4'),
      ('Juan Pablo Vélez', 3, '4.11'),
      ('Juan Pablo Vélez', 4, 'DES'),
      ('Juan Pablo Vélez', 5, '5.12'),
      ('Juan Pablo Vélez', 6, '7.3'),
      ('Juan Pablo Vélez', 7, '3.10'),
      ('Jarrison Corrales', 1, '8.2'),
      ('Jarrison Corrales', 2, '4.11'),
      ('Jarrison Corrales', 3, '11.4-7.11'),
      ('Jarrison Corrales', 4, '4.11'),
      ('Jarrison Corrales', 5, '11.4-7.10'),
      ('Jarrison Corrales', 6, '4.12'),
      ('Jarrison Corrales', 7, '11.4-7.10'),
      ('Pablo Moreno', 1, '4.11'),
      ('Pablo Moreno', 2, '4.11'),
      ('Pablo Moreno', 3, 'DES'),
      ('Pablo Moreno', 4, '11.4-7.10'),
      ('Pablo Moreno', 5, '4.12'),
      ('Pablo Moreno', 6, '11.4-7.10'),
      ('Pablo Moreno', 7, '4.12'),
      ('Jesús Polanco', 1, 'DES'),
      ('Jesús Polanco', 2, '4.11'),
      ('Jesús Polanco', 3, '4.11'),
      ('Jesús Polanco', 4, '11.4-7.10'),
      ('Jesús Polanco', 5, '5.12'),
      ('Jesús Polanco', 6, '7.3'),
      ('Jesús Polanco', 7, '11.4-7.12'),
      ('Carolina Medina', 1, '4.11'),
      ('Carolina Medina', 2, 'DES'),
      ('Carolina Medina', 3, '9.4'),
      ('Carolina Medina', 4, '4.11'),
      ('Carolina Medina', 5, '11.4-7.12'),
      ('Carolina Medina', 6, '4.12'),
      ('Carolina Medina', 7, '5.12'),
      ('Amir Salazar', 1, '8.2'),
      ('Amir Salazar', 2, '7.3'),
      ('Amir Salazar', 3, '7.3'),
      ('Amir Salazar', 4, '7.3'),
      ('Amir Salazar', 5, '7.3'),
      ('Cristina Zapata', 1, '4.11'),
      ('Cristina Zapata', 2, '11.4-7.11'),
      ('Cristina Zapata', 3, '9.4'),
      ('Cristina Zapata', 4, '9.4'),
      ('Cristina Zapata', 5, '4.11'),
      ('Cristina Zapata', 6, '4.12'),
      ('Cristina Zapata', 7, '10.5'),
      ('Gleydis Díaz', 1, '8.2'),
      ('Gleydis Díaz', 2, 'DES'),
      ('Gleydis Díaz', 3, '4.11'),
      ('Gleydis Díaz', 4, '4.11'),
      ('Gleydis Díaz', 5, '9.4'),
      ('Gleydis Díaz', 6, '7.3'),
      ('Gleydis Díaz', 7, '5.12')
    ) as v(nombre, dia, cod)
    join public.horario_personal p on p.area_id = v_area and p.nombre = v.nombre
    left join public.horario_turnos t on t.area_id = v_area and t.codigo = v.cod;
  end if;

  if not exists (select 1 from public.horario_novedades n join public.horario_personal p on p.id = n.personal_id
                 where n.area_id = v_area and p.nombre = 'Daniel Torres' and n.tipo = 'vacaciones' and n.desde = '2026-10-20') then
    insert into public.horario_novedades (area_id, personal_id, tipo, desde, hasta, nota, creado_por)
    select v_area, p.id, 'vacaciones', '2026-10-20', '2026-11-02', 'Cargado de la plantilla', 'Plantilla'
    from public.horario_personal p where p.area_id = v_area and p.nombre = 'Daniel Torres';
  end if;
end $$;

-- Debe mostrar 13 personas y dos semanas en borrador (19 oct con 85 casillas, 26 oct con 82)
select p.orden, p.nombre, e.nombre as estacion from public.horario_personal p
left join public.horario_estaciones e on e.id = p.estacion_id
join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id
where translate(lower(l.name), 'ú', 'u') like '%runico%' order by p.orden;
select s.lunes, s.estado, count(x.*) as casillas
from public.horario_semanas s join public.areas a on a.id = s.area_id join public.locations l on l.id = a.location_id
left join public.horario_asignaciones x on x.semana_id = s.id
where translate(lower(l.name), 'ú', 'u') like '%runico%' group by s.lunes, s.estado order by s.lunes;
