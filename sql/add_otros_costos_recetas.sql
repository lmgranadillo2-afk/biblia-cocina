-- Otros costos por receta (ICO, empaque, servicio, etc.), cada uno
-- monto fijo o % sobre el costo de insumos por unidad de rendimiento.
-- Se suman al costo de insumos para el food cost / margen real.
alter table recipes add column if not exists otros_costos jsonb default '[]'::jsonb;
