-- Informe semanal de bajas (lunes a domingo), generado solo cada lunes a las 11 a.m. hora
-- Colombia por un cron (pg_cron + pg_net, igual patrón que toteat-sync-diario), con las bajas
-- de todos los puntos de la semana que acaba de terminar. Solo lo ve el super admin, porque
-- mezcla datos de todos los puntos (rompería el aislamiento normal por punto/área).
-- Ya aplicado directo vía MCP; este archivo queda como referencia.

create table if not exists public.bajas_informes_semanales (
  id uuid primary key default gen_random_uuid(),
  semana_inicio date not null,
  semana_fin date not null,
  archivo_path text not null,
  cantidad_bajas int not null default 0,
  generado_at timestamptz not null default now()
);
create unique index if not exists bajas_informes_semana_idx on public.bajas_informes_semanales(semana_inicio);

alter table public.bajas_informes_semanales enable row level security;

drop policy if exists bajas_informes_select on public.bajas_informes_semanales;
create policy bajas_informes_select on public.bajas_informes_semanales for select to authenticated
  using (is_super_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('informes-bajas', 'informes-bajas', false, 5242880, array['text/csv'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "informes bajas: ver" on storage.objects;
create policy "informes bajas: ver" on storage.objects for select to authenticated
  using (bucket_id = 'informes-bajas' and is_super_admin());

notify pgrst, 'reload schema';

-- Cron: cada lunes a las 16:00 UTC (11 a.m. Colombia), llama a la Edge Function
-- "bajas-informe-semanal" (verify_jwt apagado, valida el mismo token del cron de Toteat).
select cron.schedule(
  'bajas-informe-semanal',
  '0 16 * * 1',
  $$
  select net.http_post(
    url := 'https://rwsmscggszaogalmwsrj.supabase.co/functions/v1/bajas-informe-semanal',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_ZHjOiAmgamvaTcLfluTxxA_tkhOX-Ve'
    ),
    body := jsonb_build_object('cron_token', (select token from public.toteat_cron_config where id = 1)),
    timeout_milliseconds := 120000
  );
  $$
);
