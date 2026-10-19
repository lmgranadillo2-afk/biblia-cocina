-- Eventos: estado Pendiente por confirmar / Confirmado / Cancelado.
-- Los eventos que ya existen quedan SIN estado (null): a quien los creó le sale una alerta
-- al abrir la app para definirlo. Los eventos nuevos nacen "pendiente".
-- No borra nada. Se puede correr más de una vez.

alter table public.costeo_eventos
  add column if not exists estado text,
  add column if not exists estado_por text,
  add column if not exists estado_at timestamptz;

-- El default se pone DESPUÉS de crear la columna: así solo aplica a eventos nuevos.
alter table public.costeo_eventos alter column estado set default 'pendiente';

alter table public.costeo_eventos drop constraint if exists costeo_eventos_estado_check;
alter table public.costeo_eventos add constraint costeo_eventos_estado_check
  check (estado is null or estado in ('pendiente', 'confirmado', 'cancelado'));

notify pgrst, 'reload schema';

-- Resultado: eventos sin estado por persona que los creó (a ellos les sale la alerta)
select coalesce(p.name, 'Sin creador') as creado_por, count(*) as eventos_sin_estado
from public.costeo_eventos e
left join public.profiles p on p.id = e.created_by
where e.estado is null
group by p.name
order by count(*) desc;
