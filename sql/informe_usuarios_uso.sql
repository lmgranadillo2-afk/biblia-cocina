-- SOLO LECTURA: informe de usuarios, tiempo de uso y actividad en la app. No cambia nada.
-- Una fila por usuario. Cuenta lo que cada persona crea (producciones, pedidos, bajas, facturas, chat, eventos,
-- observaciones) y lo que resuelve (pedidos aprobados/rechazados, enviados y recibidos, bajas ingresadas o denegadas,
-- producciones ingresadas al inventario, inventarios cerrados; estos se reconocen por el nombre o el correo guardado en la app). Para el informe: correrlo en el SQL Editor y descargar con "Download CSV".
--
-- Tiempo de uso (ESTIMADO): la app no guarda cuánto tiempo la tiene abierta cada persona. Se estima con el
-- registro de sesiones de Supabase (auth.audit_log_entries): mientras la app está abierta, la sesión se
-- renueva más o menos cada hora, así que "horas_con_app_abierta_30d" = horas distintas con un ingreso o
-- renovación de sesión. Es aproximado (una hora puede ser 5 minutos o 60).

with usuarios as (
  select u.id, u.email, u.created_at as creado, u.last_sign_in_at as ultimo_ingreso,
         p.name as nombre, p.role as rol, coalesce(p.is_super_admin, false) as super_admin,
         to_jsonb(p) as pj
  from auth.users u
  left join public.profiles p on p.id = u.id
),
nombres as (
  select id as uid, lower(trim(email)) as clave from usuarios where email is not null
  union select id, lower(trim(nombre)) from usuarios where nullif(trim(nombre), '') is not null
),
actividad as (
            select created_by as uid, 'produccion'  as modulo, created_at as at from public.productions
  union all select created_by, 'pedido',      created_at from public.orders
  union all select created_by, 'baja',        created_at from public.bajas
  union all select created_by, 'factura',     created_at from public.facturas
  union all select autor_id,   'chat',        created_at from public.chat_mensajes
  union all select created_by, 'evento',      created_at from public.costeo_eventos
  union all select created_by, 'observacion', created_at from public.observations
  -- Lo que hace un admin o líder: la app guarda el NOMBRE (o el correo) de quien lo hizo.
  union all select n.uid, x.modulo, x.at from (
              select resuelto_por as quien, 'pedido_revisado' as modulo, resuelto_at as at from public.orders where resuelto_at is not null
    union all select enviado_por,  'pedido_enviado',  enviado_at  from public.orders where enviado_at is not null
    union all select recibido_por, 'pedido_recibido', recibido_at from public.orders where recibido_at is not null
    union all select resuelto_por, 'baja_resuelta',   resuelto_at from public.bajas where resuelto_at is not null
    union all select cerrado_por,  'inventario',      cerrado_at  from public.inventory_sessions where cerrado_at is not null
    union all select ingresado_por, 'produccion_ingresada', ingresado_at from public.productions where ingresado_at is not null
  ) x join nombres n on n.clave = lower(trim(x.quien))
),
act as (
  select uid,
    max(at) as ultima_accion,
    count(*) filter (where modulo = 'produccion'  and at > now() - interval '30 days') as producciones_30d,
    count(*) filter (where modulo = 'pedido'      and at > now() - interval '30 days') as pedidos_30d,
    count(*) filter (where modulo = 'baja'        and at > now() - interval '30 days') as bajas_30d,
    count(*) filter (where modulo = 'inventario'  and at > now() - interval '30 days') as inventarios_cerrados_30d,
    count(*) filter (where modulo = 'pedido_revisado' and at > now() - interval '30 days') as pedidos_revisados_30d,
    count(*) filter (where modulo = 'pedido_enviado'  and at > now() - interval '30 days') as pedidos_enviados_30d,
    count(*) filter (where modulo = 'pedido_recibido' and at > now() - interval '30 days') as pedidos_recibidos_30d,
    count(*) filter (where modulo = 'baja_resuelta'   and at > now() - interval '30 days') as bajas_resueltas_30d,
    count(*) filter (where modulo = 'produccion_ingresada' and at > now() - interval '30 days') as producciones_ingresadas_30d,
    count(*) filter (where modulo = 'factura'     and at > now() - interval '30 days') as facturas_30d,
    count(*) filter (where modulo = 'chat'        and at > now() - interval '30 days') as mensajes_chat_30d,
    count(*) filter (where modulo = 'evento'      and at > now() - interval '30 days') as eventos_creados_30d,
    count(*) filter (where modulo = 'observacion' and at > now() - interval '30 days') as observaciones_30d,
    count(*) filter (where at > now() - interval '30 days') as acciones_30d,
    count(*) as acciones_historico
  from actividad where uid is not null group by uid
),
sesiones as (
  select (payload->>'actor_id')::uuid as uid, payload->>'action' as accion, created_at as at
  from auth.audit_log_entries
  where created_at > now() - interval '30 days'
    and payload->>'action' in ('login', 'token_refreshed', 'token_revoked')
    and payload->>'actor_id' ~ '^[0-9a-f-]{36}$'
),
ses as (
  select uid,
    count(*) filter (where accion = 'login') as ingresos_30d,
    count(distinct date_trunc('hour', at at time zone 'America/Bogota')) as horas_con_app_abierta_30d
  from sesiones group by uid
),
dias as (
  select uid, count(distinct d) as dias_activos_30d from (
    select uid, (at at time zone 'America/Bogota')::date as d from sesiones
    union select uid, (at at time zone 'America/Bogota')::date from actividad where at > now() - interval '30 days'
  ) x where uid is not null group by uid
),
puntos as (
  select ul.user_id, string_agg(distinct l.name, ', ' order by l.name) as puntos
  from public.user_locations ul join public.locations l on l.id = ul.location_id
  group by ul.user_id
),
areas as (
  select ua.user_id, string_agg(distinct l.name || ' · ' || a.name, ', ' order by l.name || ' · ' || a.name) as areas
  from public.user_areas ua join public.areas a on a.id = ua.area_id join public.locations l on l.id = a.location_id
  group by ua.user_id
)
select
  coalesce(nullif(u.nombre, ''), '(sin nombre)')                                   as nombre,
  u.email                                                                           as acceso,
  case when u.super_admin then 'super admin' else coalesce(u.rol, '') end           as rol,
  concat_ws(', ',
    case when (u.pj->>'es_rrhh')::boolean then 'RRHH' end,
    case when (u.pj->>'es_informes')::boolean then 'Informes' end,
    case when (u.pj->>'es_mercadeo')::boolean then 'Mercadeo' end,
    case when (u.pj->>'es_facturas')::boolean then 'Facturas' end,
    case when (u.pj->>'es_shows')::boolean then 'Shows' end,
    case when (u.pj->>'edita_seguimiento_eventos')::boolean then 'Edita eventos' end
  )                                                                                 as perfiles_especiales,
  coalesce(pt.puntos, '')                                                           as puntos,
  coalesce(ar.areas, '')                                                            as areas,
  (u.creado at time zone 'America/Bogota')::date                                    as cuenta_creada,
  to_char(u.ultimo_ingreso at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI')     as ultimo_ingreso,
  (current_date - (u.ultimo_ingreso at time zone 'America/Bogota')::date)           as dias_sin_ingresar,
  coalesce(s.ingresos_30d, 0)                                                       as ingresos_30d,
  coalesce(dd.dias_activos_30d, 0)                                                  as dias_activos_30d,
  coalesce(s.horas_con_app_abierta_30d, 0)                                          as horas_con_app_abierta_30d,
  to_char(a.ultima_accion at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI')      as ultima_accion,
  coalesce(a.producciones_30d, 0)    as producciones_30d,
  coalesce(a.pedidos_30d, 0)         as pedidos_30d,
  coalesce(a.bajas_30d, 0)           as bajas_30d,
  coalesce(a.inventarios_cerrados_30d, 0) as inventarios_cerrados_30d,
  coalesce(a.pedidos_revisados_30d, 0)  as pedidos_revisados_30d,
  coalesce(a.pedidos_enviados_30d, 0)   as pedidos_enviados_30d,
  coalesce(a.pedidos_recibidos_30d, 0)  as pedidos_recibidos_30d,
  coalesce(a.bajas_resueltas_30d, 0)    as bajas_resueltas_30d,
  coalesce(a.producciones_ingresadas_30d, 0) as producciones_ingresadas_30d,
  coalesce(a.facturas_30d, 0)        as facturas_30d,
  coalesce(a.mensajes_chat_30d, 0)   as mensajes_chat_30d,
  coalesce(a.eventos_creados_30d, 0) as eventos_creados_30d,
  coalesce(a.observaciones_30d, 0)   as observaciones_30d,
  coalesce(a.acciones_30d, 0)        as acciones_30d,
  coalesce(a.acciones_historico, 0)  as acciones_historico
from usuarios u
left join act a on a.uid = u.id
left join ses s on s.uid = u.id
left join dias dd on dd.uid = u.id
left join puntos pt on pt.user_id = u.id
left join areas ar on ar.user_id = u.id
order by coalesce(s.horas_con_app_abierta_30d, 0) desc, coalesce(a.acciones_30d, 0) desc, u.ultimo_ingreso desc nulls last;
