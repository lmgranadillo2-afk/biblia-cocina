-- REVISIÓN DE SEGURIDAD — solo lectura, no cambia nada.
-- Devuelve una sola tabla con lo que hay que revisar.
select 'Tabla SIN RLS (cualquiera con la llave pública podría leerla)' as hallazgo, c.relname as detalle
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity

union all
-- Quién puede escribir en las tablas que dan permisos (un usuario nuevo no debería poder darse acceso ni volverse admin)
select 'Política de escritura en ' || tablename, policyname || ' [' || cmd || '] ' || coalesce(qual, '') || ' / ' || coalesce(with_check, '')
from pg_policies
where schemaname = 'public' and tablename in ('profiles', 'user_locations', 'user_areas')
  and cmd in ('INSERT', 'UPDATE', 'ALL', 'DELETE')

union all
select 'Usuarios por rol', coalesce(role, '(sin rol)') || ': ' || count(*) || case when bool_or(is_super_admin) then ' (incluye super admin)' else '' end
from public.profiles group by role

union all
select 'Usuarios sin ningún punto asignado', count(*)::text
from public.profiles p where not exists (select 1 from public.user_locations ul where ul.user_id = p.id);
