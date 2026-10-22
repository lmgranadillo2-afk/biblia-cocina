-- Solo lectura: diagnóstico de las notificaciones del chat. No cambia nada.
-- 1) Dispositivos con notificaciones activas (por persona)
-- 2) Últimos mensajes del chat y quiénes debían recibir aviso
-- 3) Lo que respondió la función chat-push a cada llamada
select '1 dispositivos' as que, coalesce(p.name, '(sin nombre)') as quien,
  case when s.user_agent ilike '%iphone%' or s.user_agent ilike '%ipad%' then 'iPhone'
       when s.user_agent ilike '%android%' then 'Android' else 'Computador' end as detalle,
  split_part(split_part(s.endpoint, '//', 2), '/', 1) as extra,
  s.actualizado_at at time zone 'America/Bogota' as cuando
from public.push_suscripciones s
left join public.profiles p on p.id = s.user_id

union all
select '2 mensajes', coalesce(m.autor_nombre, '?'),
  case when c.tipo = 'punto' then 'grupo: ' || coalesce(l.name, '?') else 'directo' end,
  'debían recibir: ' || (
    case when c.tipo = 'punto'
      then (select count(*) from public.user_locations ul where ul.location_id = c.location_id and ul.user_id <> m.autor_id)
      else 1 end)::text
    || ' · con notificaciones: ' || (
    select count(*) from public.push_suscripciones s
    where s.user_id <> m.autor_id and (
      (c.tipo = 'punto' and s.user_id in (select ul.user_id from public.user_locations ul where ul.location_id = c.location_id))
      or (c.tipo = 'directo' and s.user_id in (c.usuario_a, c.usuario_b))))::text,
  m.created_at at time zone 'America/Bogota'
from (select * from public.chat_mensajes order by created_at desc limit 5) m
join public.chat_conversaciones c on c.id = m.conversacion_id
left join public.locations l on l.id = c.location_id

union all
select '3 respuesta función', null, r.status_code::text, coalesce(r.error_msg, left(r.content, 250)), r.created at time zone 'America/Bogota'
from (select * from net._http_response order by created desc limit 5) r

order by 1, 5 desc;
