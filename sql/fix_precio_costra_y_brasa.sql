-- Corrige el precio de COSTRA Y BRASA en la carta de Cantina Dos Santos ($23.000 -> $230.000).
update public.carta_items
set precio = 230000
where nombre = 'COSTRA Y BRASA'
  and location_id = (select id from public.locations where slug = 'dos-santos');
