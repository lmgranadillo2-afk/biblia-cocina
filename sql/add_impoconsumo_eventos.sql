-- Eventos: impoconsumo (8 % por defecto) sobre el consumo de carta, se suma al total.
-- Solo agrega una columna. Los eventos ya guardados quedan con 8 %; se puede cambiar por evento.
alter table public.costeo_eventos
  add column if not exists impoconsumo_pct numeric not null default 8;
