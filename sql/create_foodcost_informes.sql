-- Informes mensuales de food cost (datos de Toteat), guardados por restaurante y mes.
-- Correr UNA vez (se puede repetir sin problema). No modifica datos existentes.

create table if not exists public.foodcost_informes (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  mes date not null,                 -- primer día del mes (ej. 2026-09-01)
  datos jsonb not null,              -- resultado completo del cálculo de food cost
  origen text not null default 'manual',   -- 'manual' | 'automatico'
  generado timestamptz not null default now(),
  unique (location_id, mes)
);

alter table public.foodcost_informes enable row level security;
drop policy if exists foodcost_informes_select on public.foodcost_informes;
create policy foodcost_informes_select on public.foodcost_informes
  for select using (public.has_location_access(location_id) or public.is_eventos_user());
-- Escribe solo la función de Toteat (con la llave de servicio), por eso no hay políticas de escritura.

-- Día 1 de cada mes a las 5:00 a. m. (hora Colombia = 10:00 UTC): informe del mes anterior
-- de cada restaurante. Una llamada por restaurante (corren en paralelo); los que no tienen
-- Toteat configurado se omiten solos.
select cron.unschedule('foodcost-mensual')
where exists (select 1 from cron.job where jobname = 'foodcost-mensual');

select cron.schedule(
  'foodcost-mensual',
  '0 10 1 * *',
  $$
  select net.http_post(
    url := 'https://rwsmscggszaogalmwsrj.supabase.co/functions/v1/dynamic-endpoint',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_ZHjOiAmgamvaTcLfluTxxA_tkhOX-Ve'
    ),
    body := jsonb_build_object(
      'cron_token', (select token from public.toteat_cron_config where id = 1),
      'accion', 'foodcost_mensual',
      'location_id', l.id
    ),
    timeout_milliseconds := 300000
  )
  from public.locations l
  where l.activo and l.slug not in ('eventos', 'admin');
  $$
);

notify pgrst, 'reload schema';
