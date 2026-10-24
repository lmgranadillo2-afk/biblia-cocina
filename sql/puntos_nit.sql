-- Datos de la empresa por punto (para la colilla de pago). No borra datos; se puede correr más de una vez.
alter table public.locations add column if not exists nit text;
alter table public.locations add column if not exists razon_social text;
alter table public.locations add column if not exists direccion_fiscal text;

-- Datos tomados de los RUT (24 oct 2026)
update public.locations set nit = '901.093.339-8', razon_social = 'INVERSIONES JUNIN BAR - RESTAURANTE S.A.S', direccion_fiscal = 'CR 33 7 165, Medellín'
where slug = 'dos-santos' and lower(name) not like '%cali%';
update public.locations set nit = '901.772.126-1', razon_social = 'INVERSIONES DS CALI S.A.S.', direccion_fiscal = 'CL 16 A 122 31 LC 01, Cali'
where lower(name) like '%cali%';
update public.locations set nit = '901.636.592-7', razon_social = 'INVERSIONES MSTZ S.A.S.', direccion_fiscal = 'CL 6 A 29 126, Medellín'
where translate(lower(name), 'ú', 'u') like '%runico%';
update public.locations set nit = '901.906.390-5', razon_social = 'INVERSIONES CANTA CORAZON S.A.S.', direccion_fiscal = 'CL 6 A 29 78, Medellín'
where lower(name) like '%canta%';

notify pgrst, 'reload schema';

-- Debe mostrar Cantina Dos Santos Medellín, Cali, Rúnico y Canta Corazón con su NIT
select name, slug, nit, razon_social, direccion_fiscal from public.locations order by name;
