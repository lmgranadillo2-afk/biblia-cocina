-- Eventos: encargado del evento y su comisión (% sobre el COSTO de la carta del evento).
-- Dato interno: solo se muestra a admin y se descuenta de la ganancia.
-- Solo agrega columnas; no modifica eventos existentes.
alter table public.costeo_eventos
  add column if not exists encargado text,
  add column if not exists comision_pct numeric not null default 0;
