-- Regla de Horarios: cuántas personas deben cerrar cada día, por área (0 = sin regla).
-- Cierran quienes salen a la última hora del día. Barra de Cantina Dos Santos Medellín queda en 2.
-- No borra datos.
alter table public.horario_config add column if not exists cierre_minimo smallint not null default 0;

update public.horario_config c set cierre_minimo = 2
from public.areas a join public.locations l on l.id = a.location_id
where c.area_id = a.id and l.slug = 'dos-santos' and lower(l.name) not like '%cali%' and upper(trim(a.name)) like 'BARRA%';

notify pgrst, 'reload schema';

-- Debe mostrar Barra con 2
select l.name, a.name, c.cierre_minimo from public.horario_config c
join public.areas a on a.id = c.area_id join public.locations l on l.id = a.location_id
where c.cierre_minimo > 0;
