-- Mermas del mes de cocina (valor de lo transferido a la bodega de bajas en Toteat).
-- Solo agrega una columna. Se puede correr más de una vez.
alter table public.foodcost_cocina add column if not exists mermas numeric;

notify pgrst, 'reload schema';
