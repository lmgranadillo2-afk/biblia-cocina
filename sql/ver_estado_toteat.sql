-- Solo lectura: estado de la integración con Toteat. No cambia nada.
-- Una fila por restaurante y tipo de sincronización (carta / costos) con la última corrida,
-- cuántas fallaron en los últimos 14 días y el último error o aviso de revisión.
-- Al final, las últimas corridas de la tarea programada (cron) y la respuesta de la función.

select
  'sincronización' as que,
  l.name as restaurante,
  s.origen,
  max(s.creado) at time zone 'America/Bogota' as ultima_vez,
  count(*) filter (where s.creado > now() - interval '14 days') as corridas_14d,
  count(*) filter (where s.creado > now() - interval '14 days' and (s.error is not null or s.resumen->>'revision' is not null)) as con_problema_14d,
  (array_agg(coalesce(s.error, s.resumen->>'revision') order by s.creado desc) filter (where s.error is not null or s.resumen->>'revision' is not null))[1] as ultimo_problema,
  (array_agg(s.resumen order by s.creado desc))[1]::text as ultimo_resumen
from public.toteat_sync_log s
join public.locations l on l.id = s.location_id
group by l.name, s.origen

union all

-- Tarea programada: ¿corrió cada madrugada?
select 'cron', j.jobname, d.status, d.start_time at time zone 'America/Bogota', null, null, d.return_message, null
from cron.job_run_details d
join cron.job j on j.jobid = d.jobid
where j.jobname like 'toteat%' and d.start_time > now() - interval '7 days'

union all

-- Respuesta de la función a las llamadas del cron (código HTTP y comienzo del cuerpo)
select 'respuesta función', null, r.status_code::text, r.created at time zone 'America/Bogota', null, null,
  coalesce(r.error_msg, left(r.content, 300)), r.timed_out::text
from net._http_response r
where r.created > now() - interval '7 days'

order by 1, 2, 4 desc;
