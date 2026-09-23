-- Costos de PULPO PARRILLA y COSTRA Y BRASA ajustados a margen de 58% sobre el precio de venta
-- (costo = 42% del precio): pulpo $100.000 -> $42.000; costra y brasa $230.000 -> $96.600.
update public.carta_items ci
set costo = v.costo
from (values
('PULPO PARRILLA', 42000),
('COSTRA Y BRASA', 96600)
) as v(nombre, costo)
where ci.nombre = v.nombre
  and ci.location_id = (select id from public.locations where slug = 'dos-santos');
