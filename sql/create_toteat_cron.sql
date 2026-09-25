-- Sincronización automática de la carta con Toteat, todos los días a las 4:00 a. m. (hora Colombia).
-- Correr UNA vez. No modifica datos existentes.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Token interno que usa la tarea programada para identificarse ante la función.
-- Se genera solo, vive únicamente en la base y nadie lo tiene que copiar ni escribir.
create table if not exists public.toteat_cron_config (
  id int primary key default 1 check (id = 1),
  token text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
);
alter table public.toteat_cron_config enable row level security;  -- sin políticas: nadie la lee desde la app
insert into public.toteat_cron_config (id) values (1) on conflict (id) do nothing;

-- Historial de sincronizaciones (manuales y automáticas).
create table if not exists public.toteat_sync_log (
  id bigserial primary key,
  location_id uuid not null references public.locations(id),
  creado timestamptz not null default now(),
  origen text not null,            -- 'manual' | 'automatico'
  aplicado boolean not null default false,
  resumen jsonb,                   -- conteos: cambios de precio, nuevos, desactivados, revisión
  error text
);
alter table public.toteat_sync_log enable row level security;
drop policy if exists toteat_sync_log_select on public.toteat_sync_log;
create policy toteat_sync_log_select on public.toteat_sync_log
  for select using (public.has_location_access(location_id) or public.is_eventos_user());

-- Tarea diaria: 09:00 UTC = 4:00 a. m. en Colombia.
select cron.unschedule('toteat-sync-diario')
where exists (select 1 from cron.job where jobname = 'toteat-sync-diario');

select cron.schedule(
  'toteat-sync-diario',
  '0 9 * * *',
  $$
  select net.http_post(
    url := 'https://rwsmscggszaogalmwsrj.supabase.co/functions/v1/dynamic-endpoint',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_ZHjOiAmgamvaTcLfluTxxA_tkhOX-Ve'
    ),
    body := jsonb_build_object('cron_token', (select token from public.toteat_cron_config where id = 1)),
    timeout_milliseconds := 150000
  );
  $$
);
