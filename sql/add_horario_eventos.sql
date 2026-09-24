-- Eventos: horario en texto libre para la portada de la cotización (ej. "12:30 pm a 6:00 pm").
-- Solo agrega una columna.
alter table public.costeo_eventos
  add column if not exists horario text;
