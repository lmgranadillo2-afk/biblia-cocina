-- Prueba: ejecuta ahora la sincronización automática con Toteat (la misma que corre a las 4:00 a. m.).
select net.http_post(
  url := 'https://rwsmscggszaogalmwsrj.supabase.co/functions/v1/dynamic-endpoint',
  headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', 'sb_publishable_ZHjOiAmgamvaTcLfluTxxA_tkhOX-Ve'),
  body := jsonb_build_object('cron_token', (select token from public.toteat_cron_config where id = 1)),
  timeout_milliseconds := 150000
);
