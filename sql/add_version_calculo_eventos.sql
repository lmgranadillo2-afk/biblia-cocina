-- Eventos: versión del cálculo de la cotización, para no cambiar las ya hechas.
--   1 = como antes: "Servicio" calculado sobre el total con ICO (eventos existentes).
--   2 = legal (Ley 1935 de 2018): "Propina voluntaria sugerida", máx. 10 %, sobre el valor sin ICO,
--       con la nota de voluntariedad (eventos nuevos).
-- Solo agrega una columna; los eventos existentes quedan en 1.
alter table public.costeo_eventos
  add column if not exists version_calculo integer not null default 1;

notify pgrst, 'reload schema';
