-- Módulo Horarios — paso 2: carga inicial de Cocina de Cantina Dos Santos Medellín y activación del módulo.
-- Correr DESPUÉS de horarios_1_tablas.sql. No borra nada; si algo ya existe lo deja como está. Se puede correr más de una vez.
-- "Cocinero (nuevo)" y "Auxiliar (nuevo)" se renombran después en Horarios → Configuración.

do $$
declare
  v_area uuid;
  e_prod uuid; e_lider uuid; e_parr uuid; e_fria uuid; e_tacos uuid; e_stew uuid;
begin
  select a.id into v_area
  from public.areas a join public.locations l on l.id = a.location_id
  where l.slug = 'dos-santos' and lower(trim(a.name)) = 'cocina';
  if v_area is null then raise exception 'No encontré el área Cocina de Cantina Dos Santos (slug dos-santos)'; end if;

  -- Activar el módulo en el área
  update public.areas set modules = coalesce(modules, '[]'::jsonb) || '["horarios"]'::jsonb
  where id = v_area and not coalesce(modules, '[]'::jsonb) @> '["horarios"]'::jsonb;

  -- Reglas (jornada máxima 42 h: se avisa, no bloquea; vie-sáb-dom sin descansos salvo producción)
  insert into public.horario_config (area_id) values (v_area) on conflict (area_id) do nothing;

  -- Estaciones y mínimos por día (L-D)
  insert into public.horario_estaciones (area_id, nombre, color, minimo_por_dia, orden) values
    (v_area, 'Producción', 1, '{2,2,2,2,2,2,0}', 1),
    (v_area, 'Líder',      2, '{1,1,1,1,1,1,1}', 2),
    (v_area, 'Parrilla',   3, '{1,1,1,1,1,1,1}', 3),
    (v_area, 'Fría',       4, '{1,1,1,1,2,2,2}', 4),
    (v_area, 'Tacos',      5, '{1,1,1,1,1,1,1}', 5),
    (v_area, 'Steward',    6, '{1,1,1,1,1,1,1}', 6)
  on conflict (area_id, nombre) do nothing;

  select id into e_prod  from public.horario_estaciones where area_id = v_area and nombre = 'Producción';
  select id into e_lider from public.horario_estaciones where area_id = v_area and nombre = 'Líder';
  select id into e_parr  from public.horario_estaciones where area_id = v_area and nombre = 'Parrilla';
  select id into e_fria  from public.horario_estaciones where area_id = v_area and nombre = 'Fría';
  select id into e_tacos from public.horario_estaciones where area_id = v_area and nombre = 'Tacos';
  select id into e_stew  from public.horario_estaciones where area_id = v_area and nombre = 'Steward';

  -- Turnos (horas tal cual, confirmadas por Miguel)
  insert into public.horario_turnos (area_id, codigo, horas, cubre_manana, cubre_cierre, orden) values
    (v_area, '6-1',          7,   true,  false, 1),
    (v_area, '11-5',         6,   true,  false, 2),
    (v_area, '11,30-4-7-11', 8.5, true,  true,  3),
    (v_area, '1-4-7-12',     8,   true,  true,  4),
    (v_area, '3-11',         8,   false, true,  5),
    (v_area, '4-12',         8,   false, true,  6),
    (v_area, '5-1',          8,   false, true,  7)
  on conflict (area_id, codigo) do nothing;

  -- Tarea diaria
  insert into public.horario_tareas (area_id, nombre, detalle, orden) values
    (v_area, 'Bunker', 'Aseo del vestier', 1)
  on conflict (area_id, nombre) do nothing;

  -- Personal (descanso: 1 = lunes … 7 = domingo)
  insert into public.horario_personal (area_id, nombre, estacion_id, cargo, descanso_dia, es_produccion, orden) values
    (v_area, 'Dolca',            e_prod,  'Producción', 7, true,  1),
    (v_area, 'Nubia',            e_prod,  'Producción', 7, true,  2),
    (v_area, 'Jany',             e_lider, 'Líder',      1, false, 3),
    (v_area, 'Cocinero (nuevo)', e_lider, 'Cocinero',   2, false, 4),
    (v_area, 'Edinnson',         e_parr,  'Cocinero',   2, false, 5),
    (v_area, 'Mauricio',         e_parr,  'Cocinero',   1, false, 6),
    (v_area, 'Verónica',         e_fria,  'Cocinero',   1, false, 7),
    (v_area, 'José Rod',         e_fria,  'Cocinero',   4, false, 8),
    (v_area, 'Auxiliar (nuevo)', e_fria,  'Auxiliar',   3, false, 9),
    (v_area, 'Omar',             e_tacos, 'Cocinero',   1, false, 10),
    (v_area, 'Jesús',            e_tacos, 'Cocinero',   2, false, 11),
    (v_area, 'Martha',           e_stew,  'Steward',    2, false, 12),
    (v_area, 'Victoria',         e_stew,  'Steward',    4, false, 13)
  on conflict (area_id, nombre) do nothing;
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar: 6 estaciones, 7 turnos, 1 tarea, 13 personas y el módulo activo (true)
select
  (select count(*) from public.horario_estaciones e join public.areas a on a.id = e.area_id join public.locations l on l.id = a.location_id where l.slug = 'dos-santos') as estaciones,
  (select count(*) from public.horario_turnos t join public.areas a on a.id = t.area_id join public.locations l on l.id = a.location_id where l.slug = 'dos-santos') as turnos,
  (select count(*) from public.horario_tareas t join public.areas a on a.id = t.area_id join public.locations l on l.id = a.location_id where l.slug = 'dos-santos') as tareas,
  (select count(*) from public.horario_personal p join public.areas a on a.id = p.area_id join public.locations l on l.id = a.location_id where l.slug = 'dos-santos') as personas,
  (select bool_or(a.modules @> '["horarios"]'::jsonb) from public.areas a join public.locations l on l.id = a.location_id where l.slug = 'dos-santos' and lower(trim(a.name)) = 'cocina') as modulo_activo;
