-- Módulo Horarios — paso 13: descanso de todo el equipo y descanso rotativo. Correr después de horarios_1 a 12.
-- No borra datos; se puede correr más de una vez. El descanso fijo de cada persona se conserva (rige para semanas anteriores).
--
-- Decisiones de Miguel (24 oct 2026):
--  * Cantina Dos Santos Medellín: descanso rotativo hasta el domingo 1 de noviembre de 2026; desde el lunes 2 rige el descanso fijo de cada persona.
--  * Cantina Dos Santos Cali: todo el equipo descansa el lunes.
--  * Canta Corazón: todo el equipo descansa domingo y lunes.

alter table public.horario_config add column if not exists descanso_todos smallint[] not null default '{}';
alter table public.horario_config add column if not exists descanso_rotativo_desde date;
alter table public.horario_config add column if not exists descanso_rotativo_hasta date;

-- Que todas las áreas con Horarios tengan su fila de configuración
insert into public.horario_config (area_id)
select a.id from public.areas a where a.modules @> '["horarios"]'::jsonb
on conflict (area_id) do nothing;

-- Medellín: rotativo hasta el 1 de noviembre; luego descanso fijo
update public.horario_config c set descanso_rotativo_desde = null, descanso_rotativo_hasta = '2026-11-01', descanso_todos = '{}'
from public.areas a join public.locations l on l.id = a.location_id
where c.area_id = a.id and l.slug = 'dos-santos' and lower(l.name) not like '%cali%';

-- Cali: lunes para todos
update public.horario_config c set descanso_todos = '{1}', descanso_rotativo_desde = null, descanso_rotativo_hasta = null
from public.areas a join public.locations l on l.id = a.location_id
where c.area_id = a.id and lower(l.name) like '%cali%';

-- Canta Corazón: domingo y lunes para todos
update public.horario_config c set descanso_todos = '{7,1}', descanso_rotativo_desde = null, descanso_rotativo_hasta = null
from public.areas a join public.locations l on l.id = a.location_id
where c.area_id = a.id and lower(l.name) like '%canta%';

notify pgrst, 'reload schema';

-- Debe mostrar Medellín con rotativo hasta 2026-11-01, Cali con {1} y Canta Corazón con {7,1}
select l.name as punto, a.name as area, c.descanso_todos, c.descanso_rotativo_desde, c.descanso_rotativo_hasta
from public.horario_config c join public.areas a on a.id = c.area_id join public.locations l on l.id = a.location_id
order by 1, 2;
