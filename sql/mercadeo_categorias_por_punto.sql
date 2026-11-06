-- Mercadeo: cada restaurante tiene sus propias categorías (decisión de Miguel, 5 nov 2026).
-- Las categorías que ya existían se crearon y usaron en Canta Corazón (todo su presupuesto está ahí): quedan de Canta Corazón,
-- con la misma clave, así sus presupuestos no cambian. Los demás restaurantes arrancan con las 4 de base.
-- Un presupuesto o gasto solo puede usar categorías de su mismo restaurante. No borra datos; se puede correr más de una vez.
alter table public.mercadeo_categorias add column if not exists location_id uuid references public.locations(id) on delete cascade;
update public.mercadeo_categorias set location_id = (select id from public.locations where name = 'Canta Corazon') where location_id is null;

-- El nombre único pasa a ser por restaurante (antes de crear las de base, que repiten nombres).
drop index if exists public.mercadeo_categorias_nombre_idx;
create unique index if not exists mercadeo_categorias_nombre_loc_idx on public.mercadeo_categorias (location_id, lower(btrim(nombre)));

insert into public.mercadeo_categorias (location_id, nombre, orden)
select l.id, v.nombre, v.orden
from public.locations l
cross join (values ('Pauta digital', 1), ('Influencers y contenido', 2), ('Impresos y POP', 3), ('Activaciones y eventos', 4)) as v(nombre, orden)
where l.activo is not false and l.slug not in ('admin', 'eventos')
  and not exists (select 1 from public.mercadeo_categorias c where c.location_id = l.id);

alter table public.mercadeo_categorias alter column location_id set not null;
create unique index if not exists mercadeo_categorias_nombre_loc_idx on public.mercadeo_categorias (location_id, lower(btrim(nombre)));
alter table public.mercadeo_categorias drop constraint if exists mercadeo_categorias_clave_loc_key;
alter table public.mercadeo_categorias add constraint mercadeo_categorias_clave_loc_key unique (clave, location_id);

alter table public.mercadeo_presupuestos drop constraint if exists mercadeo_presupuestos_categoria_fkey;
alter table public.mercadeo_gastos drop constraint if exists mercadeo_gastos_categoria_fkey;
alter table public.mercadeo_presupuestos add constraint mercadeo_presupuestos_categoria_fkey
  foreign key (categoria, location_id) references public.mercadeo_categorias (clave, location_id);
alter table public.mercadeo_gastos add constraint mercadeo_gastos_categoria_fkey
  foreign key (categoria, location_id) references public.mercadeo_categorias (clave, location_id);

notify pgrst, 'reload schema';

-- Debe mostrar cuántas categorías tiene cada restaurante
select l.name, count(*) categorias, count(*) filter (where c.activa) activas
from public.mercadeo_categorias c join public.locations l on l.id = c.location_id group by l.name order by l.name;
