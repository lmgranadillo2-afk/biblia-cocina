-- Solo lectura: muestra el código de las funciones que salieron en la revisión de seguridad,
-- para revisar si validan quién las llama. No cambia nada.
select p.proname as funcion, pg_get_functiondef(p.oid) as codigo
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('delete_location_cascade', 'proteger_super_admin', 'handle_new_user',
                    'check_same_day_production', 'admin_location_id', 'eventos_location_id')
order by p.proname;
