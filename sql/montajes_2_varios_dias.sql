-- Montajes de varios días: fecha "Desde" (fecha) y "Hasta" (fecha_fin, opcional).
-- No borra datos. Se puede correr más de una vez. Necesita sql/montajes.sql corrido antes.
alter table public.montajes add column if not exists fecha_fin date;

alter table public.montajes drop constraint if exists montajes_fecha_fin_check;
alter table public.montajes add constraint montajes_fecha_fin_check
  check (fecha_fin is null or (fecha is not null and fecha_fin >= fecha));

notify pgrst, 'reload schema';

-- Revisión: debe salir fecha_fin.
select column_name from information_schema.columns where table_schema = 'public' and table_name = 'montajes' and column_name = 'fecha_fin';
