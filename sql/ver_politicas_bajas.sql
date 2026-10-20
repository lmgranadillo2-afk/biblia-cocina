-- Solo lectura: políticas y columnas actuales de la tabla bajas (para separarlas por área). No cambia nada.
select 'politica' as tipo, policyname as nombre, cmd as detalle, coalesce(qual, '') || ' / ' || coalesce(with_check, '') as regla
from pg_policies where schemaname = 'public' and tablename = 'bajas'
union all
select 'columna', column_name, data_type, ''
from information_schema.columns where table_schema = 'public' and table_name = 'bajas'
union all
select 'conteo', 'bajas existentes', count(*)::text, count(distinct location_id)::text || ' puntos'
from public.bajas
order by 1, 2;
