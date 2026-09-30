-- Restaurantes que usan la carta de otro: Dos Santos Cali usa la carta (y precios) de Cantina Dos Santos.
-- Solo agrega una columna, la llena para Cali y permite leer esa carta. No toca datos de la carta.
alter table public.locations
  add column if not exists carta_origen_id uuid references public.locations(id);

update public.locations
set carta_origen_id = (select id from public.locations where slug = 'dos-santos')
where slug like 'dos-santos-cali%';

-- Quien tiene acceso a un restaurante puede leer la carta que ese restaurante usa.
drop policy if exists carta_items_select_origen on public.carta_items;
create policy carta_items_select_origen on public.carta_items
  for select using (exists (
    select 1 from public.locations l
    where l.carta_origen_id = carta_items.location_id and public.has_location_access(l.id)
  ));

notify pgrst, 'reload schema';
