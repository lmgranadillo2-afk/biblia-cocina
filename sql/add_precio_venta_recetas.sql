-- Precio de venta por receta, usado para calcular % food cost / margen
-- en la calculadora de costos del recetario. Queda en NULL para subrecetas
-- (fondos, salsas, etc.) que no se venden directo.
alter table recipes add column if not exists precio_venta numeric;
