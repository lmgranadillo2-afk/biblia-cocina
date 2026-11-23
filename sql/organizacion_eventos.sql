-- Organización por secciones (Junín Operaciones, 23 nov 2026, decisiones de Miguel):
--   * Eventos es una pestaña propia (salió de Costeo). Las áreas que tenían "costeo" la siguen viendo.
--   * El punto Eventos ve SOLO lo de eventos: sus áreas quedan con el módulo "eventos" (sin Costeo/Carta).
--     Montajes y Chat los ve igual (no dependen de módulos). Admin, Calculadora y RRHH se esconden en ese punto.
--   * Shows va con Eventos: el usuario de Eventos (eventosgrupojunin@) también lo ve y edita.
-- No borra datos. Cambia los módulos de las áreas del punto Eventos (se puede revertir poniéndoles "costeo").

-- Antes: módulos actuales de las áreas del punto Eventos
select 'antes' as momento, l.name as punto, a.name as area, a.modules
from public.areas a join public.locations l on l.id = a.location_id
where l.slug = 'eventos';

update public.areas a set modules = '["eventos"]'::jsonb
from public.locations l
where l.id = a.location_id and l.slug = 'eventos';

update public.profiles p set es_shows = true
from auth.users u
where u.id = p.id and lower(u.email) = 'eventosgrupojunin@cantinadossantos.com';

notify pgrst, 'reload schema';

-- Después: deben quedar con ["eventos"], y Shows para el usuario de Eventos.
select 'despues' as momento, l.name as punto, a.name as area, a.modules::text as detalle
from public.areas a join public.locations l on l.id = a.location_id
where l.slug = 'eventos'
union all
select 'shows', u.email, '', p.es_shows::text
from public.profiles p join auth.users u on u.id = p.id
where lower(u.email) = 'eventosgrupojunin@cantinadossantos.com';
