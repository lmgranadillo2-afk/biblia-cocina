-- Mercadeo: categorías editables desde la app (decisión de Miguel, 5 nov 2026). Se agregan, renombran u ocultan;
-- no se borran (los gastos y presupuestos viejos las siguen usando). Las 4 iniciales conservan su clave.
-- No borra datos; se puede correr más de una vez.
create table if not exists public.mercadeo_categorias (
  clave text primary key default gen_random_uuid()::text,
  nombre text not null check (btrim(nombre) <> ''),
  orden int not null default 100,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists mercadeo_categorias_nombre_idx on public.mercadeo_categorias (lower(btrim(nombre)));
insert into public.mercadeo_categorias (clave, nombre, orden) values
  ('pauta', 'Pauta digital', 1), ('influencers', 'Influencers y contenido', 2),
  ('impresos', 'Impresos y POP', 3), ('activaciones', 'Activaciones y eventos', 4)
on conflict (clave) do nothing;

alter table public.mercadeo_categorias enable row level security;
drop policy if exists mercadeo_categorias_ver on public.mercadeo_categorias;
drop policy if exists mercadeo_categorias_crear on public.mercadeo_categorias;
drop policy if exists mercadeo_categorias_editar on public.mercadeo_categorias;
create policy mercadeo_categorias_ver on public.mercadeo_categorias for select to authenticated using (public.puede_mercadeo());
create policy mercadeo_categorias_crear on public.mercadeo_categorias for insert to authenticated with check (public.puede_mercadeo());
create policy mercadeo_categorias_editar on public.mercadeo_categorias for update to authenticated using (public.puede_mercadeo()) with check (public.puede_mercadeo());

-- La categoría ya no es una lista fija: ahora debe existir en mercadeo_categorias.
alter table public.mercadeo_presupuestos drop constraint if exists mercadeo_presupuestos_categoria_check;
alter table public.mercadeo_gastos drop constraint if exists mercadeo_gastos_categoria_check;
alter table public.mercadeo_presupuestos drop constraint if exists mercadeo_presupuestos_categoria_fkey;
alter table public.mercadeo_gastos drop constraint if exists mercadeo_gastos_categoria_fkey;
alter table public.mercadeo_presupuestos add constraint mercadeo_presupuestos_categoria_fkey foreign key (categoria) references public.mercadeo_categorias(clave);
alter table public.mercadeo_gastos add constraint mercadeo_gastos_categoria_fkey foreign key (categoria) references public.mercadeo_categorias(clave);

notify pgrst, 'reload schema';

-- Debe mostrar las 4 categorías iniciales
select clave, nombre, orden, activa from public.mercadeo_categorias order by orden;
