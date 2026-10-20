-- Solo lectura: cómo están en el catálogo los códigos que los listados de barra usan distinto. No cambia nada.
-- SLIC013 / SLIC014: Dos Santos dice 013 = Coca regular, 014 = Zero; Canta Corazón dice lo contrario.
-- LIC281: Dos Santos lo usa para VICHE HERENCIA GUAPIREÑA; Canta Corazón para MD. ANTIOQUEÑO VERDE.
-- LIC100 / LIC101: Canta Corazón usa los dos para Hennessy.
-- ABA106 / BAR093: miel de agave (cocina vs barra).
select code, name, categoria, unidad
from public.group_ingredients
where code in ('SLIC013', 'SLIC014', 'LIC281', 'LIC100', 'LIC101', 'ABA106', 'BAR093', 'BAR045')
order by code;
