-- Módulo Horarios — paso 4: hora de entrada y salida de cada turno (tramos) y horario nocturno.
-- Sirve para saber cuántas horas de cada turno son diurnas y cuántas nocturnas (base de la pre-nómina).
-- No borra datos. Se puede correr más de una vez. Correr después de horarios_1, 2 y 3.
--
-- Tramos: lista de {"desde":"HH:MM","hasta":"HH:MM"}. Si "hasta" es menor o igual que "desde", termina al día siguiente
-- (ej. 17:00 → 01:00). Un turno partido tiene dos tramos (ej. 11:30–16:00 y 19:00–23:00).
-- Nocturno por defecto: 7 p. m. a 6 a. m. (reforma laboral, Ley 2466 de 2025). Se cambia en Horarios → Configuración.

alter table public.horario_turnos add column if not exists tramos jsonb not null default '[]'::jsonb;
alter table public.horario_asignaciones add column if not exists tramos jsonb not null default '[]'::jsonb;
alter table public.horario_config
  add column if not exists nocturno_desde time not null default '19:00',
  add column if not exists nocturno_hasta time not null default '06:00';

-- Tramos de los turnos de Cocina de Cantina Dos Santos (solo si todavía no tienen). Revisar en Configuración.
update public.horario_turnos t
set tramos = v.tramos
from (values
  ('6-1',          '[{"desde":"06:00","hasta":"13:00"}]'::jsonb),
  ('11-5',         '[{"desde":"11:00","hasta":"17:00"}]'::jsonb),
  ('11,30-4-7-11', '[{"desde":"11:30","hasta":"16:00"},{"desde":"19:00","hasta":"23:00"}]'::jsonb),
  ('1-4-7-12',     '[{"desde":"13:00","hasta":"16:00"},{"desde":"19:00","hasta":"00:00"}]'::jsonb),
  ('3-11',         '[{"desde":"15:00","hasta":"23:00"}]'::jsonb),
  ('4-12',         '[{"desde":"16:00","hasta":"00:00"}]'::jsonb),
  ('5-1',          '[{"desde":"17:00","hasta":"01:00"}]'::jsonb)
) as v(codigo, tramos)
where t.codigo = v.codigo and t.tramos = '[]'::jsonb
  and t.area_id in (select a.id from public.areas a join public.locations l on l.id = a.location_id
                    where l.slug = 'dos-santos' and lower(trim(a.name)) = 'cocina');

-- Las casillas ya armadas toman los tramos de su turno.
update public.horario_asignaciones a
set tramos = t.tramos
from public.horario_turnos t
where a.turno_id = t.id and a.tipo = 'turno' and a.tramos = '[]'::jsonb and t.tramos <> '[]'::jsonb;

notify pgrst, 'reload schema';

-- Debe mostrar los 7 turnos de Cocina Dos Santos con sus tramos
select t.codigo, t.horas, t.tramos
from public.horario_turnos t join public.areas a on a.id = t.area_id join public.locations l on l.id = a.location_id
where l.slug = 'dos-santos' and lower(trim(a.name)) = 'cocina'
order by t.orden;
