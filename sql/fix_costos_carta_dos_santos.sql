-- Corrige costos de la carta de Cantina Dos Santos que venían mal desde Toteat.
update public.carta_items ci
set costo = v.costo
from (values
('COSTILLA BBQ DE GUAYABA', 17000),
('AD.TINGA DE POLLO', 2300),
('BT.VEUVE CLICOUT BRUT', 407000)
) as v(nombre, costo)
where ci.nombre = v.nombre
  and ci.location_id = (select id from public.locations where slug = 'dos-santos');
