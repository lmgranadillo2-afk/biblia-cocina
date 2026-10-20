-- REVISIÓN DE SEGURIDAD (2) — solo lectura, no cambia nada.
-- Devuelve una tabla: nivel (ALTO / MEDIO / INFO), hallazgo y detalle. Pegar el resultado completo.

with
pol as (
  select tablename, policyname, cmd, roles::text as roles, coalesce(qual, '') as qual, coalesce(with_check, '') as chk
  from pg_policies where schemaname = 'public'
),
fn as (
  select p.proname, p.oid, p.prosecdef, p.proconfig,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
)

-- 1) Tablas sin RLS: con la llave pública cualquiera podría leerlas/escribirlas
select 'ALTO' as nivel, 'Tabla SIN RLS' as hallazgo, c.relname::text as detalle
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity

union all
-- 2) Políticas que dejan pasar a todos (true) — revisar si es intencional
select case when cmd = 'SELECT' then 'MEDIO' else 'ALTO' end,
       'Política abierta (true) en ' || tablename,
       policyname || ' [' || cmd || '] roles=' || roles || ' using=' || qual || ' check=' || chk
from pol
where qual in ('true', '(true)') or chk in ('true', '(true)')

union all
-- 3) Escritura en tablas que dan permisos: un usuario no debería darse acceso ni volverse admin
select 'INFO', 'Política de escritura en ' || tablename,
       policyname || ' [' || cmd || '] using=' || qual || ' check=' || chk
from pol
where tablename in ('profiles', 'user_locations', 'user_areas', 'locations', 'areas')
  and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')

union all
-- 3b) Escritura en pedidos y bajas: ¿alguien de cocina podría aprobarse su propio pedido o baja?
select 'INFO', 'Política de escritura en ' || tablename,
       policyname || ' [' || cmd || '] using=' || qual || ' check=' || chk
from pol
where tablename in ('orders', 'order_items', 'bajas', 'productions', 'inventory_sessions')
  and cmd in ('UPDATE', 'ALL', 'DELETE')

union all
-- 3c) Triggers en pedidos y bajas (pueden ser los que protegen el estado)
select 'INFO', 'Trigger en ' || c.relname, t.tgname || ' → ' || p.proname
from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('orders', 'bajas') and not t.tgisinternal

union all
-- 4) Triggers en profiles (deben impedir que alguien se cambie el rol o la marca super admin)
select 'INFO', 'Trigger en profiles', t.tgname || ' → ' || p.proname
from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_proc p on p.oid = t.tgfoid
where c.relname = 'profiles' and not t.tgisinternal

union all
-- 5) Funciones SECURITY DEFINER sin search_path fijo (riesgo de secuestro de esquema)
select 'MEDIO', 'Función security definer SIN search_path', proname || '(' || args || ')'
from fn
where prosecdef and not exists (select 1 from unnest(coalesce(proconfig, '{}')) x where x like 'search_path=%')

union all
-- 6) Funciones SECURITY DEFINER que puede ejecutar un visitante sin sesión (anon)
select 'MEDIO', 'Función security definer ejecutable por anon', proname || '(' || args || ')'
from fn
where prosecdef and anon_exec

union all
-- 7) Vistas en public: se saltan la RLS salvo que tengan security_invoker
select 'MEDIO', 'Vista sin security_invoker (se salta la RLS)', c.relname::text
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
  and not coalesce((select bool_or(o like 'security_invoker=%true%' or o = 'security_invoker=on') from unnest(coalesce(c.reloptions, '{}')) o), false)

union all
-- 8) Buckets de almacenamiento públicos (cualquiera con el enlace ve los archivos)
select 'MEDIO', 'Bucket de Storage público', b.name
from storage.buckets b where b.public

union all
-- 9) Cuentas: super admins, admins y cuentas sin acceso a ningún punto (posibles registros abiertos)
select 'INFO', 'Super admins', string_agg(coalesce(p.name, '(sin nombre)') || ' <' || coalesce(u.email, '?') || '>', ', ')
from public.profiles p left join auth.users u on u.id = p.id where p.is_super_admin
union all
select 'INFO', 'Usuarios por rol', coalesce(role, '(sin rol)') || ': ' || count(*) from public.profiles group by role
union all
select case when count(*) > 0 then 'MEDIO' else 'INFO' end, 'Cuentas sin ningún punto asignado',
       count(*) || coalesce(' → ' || string_agg(coalesce(u.email, p.id::text), ', '), '')
from public.profiles p left join auth.users u on u.id = p.id
where not exists (select 1 from public.user_locations ul where ul.user_id = p.id)
union all
select 'INFO', 'Cuentas que nunca han entrado', count(*)::text from auth.users where last_sign_in_at is null
union all
select 'INFO', 'Cuentas sin correo confirmado', count(*)::text from auth.users where email_confirmed_at is null

order by 1, 2, 3;
