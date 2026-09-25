-- Food cost: a qué grupo pertenece cada categoría de Toteat, por restaurante.
-- grupo: 'cocina' | 'barra' | 'excluir' (no es comida ni bebida: covers, merch, etc.)
-- Solo crea una tabla nueva.
create table if not exists public.foodcost_grupos (
  location_id uuid not null references public.locations(id),
  categoria text not null,
  grupo text not null check (grupo in ('cocina', 'barra', 'excluir')),
  updated_at timestamptz not null default now(),
  primary key (location_id, categoria)
);

alter table public.foodcost_grupos enable row level security;

drop policy if exists foodcost_grupos_select on public.foodcost_grupos;
drop policy if exists foodcost_grupos_insert on public.foodcost_grupos;
drop policy if exists foodcost_grupos_update on public.foodcost_grupos;

create policy foodcost_grupos_select on public.foodcost_grupos
  for select using (public.has_location_access(location_id) or public.is_eventos_user());
create policy foodcost_grupos_insert on public.foodcost_grupos
  for insert with check (public.is_admin() and (public.has_location_access(location_id) or public.is_eventos_user()));
create policy foodcost_grupos_update on public.foodcost_grupos
  for update using (public.is_admin() and (public.has_location_access(location_id) or public.is_eventos_user()));
