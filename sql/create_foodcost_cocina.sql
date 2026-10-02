-- Food cost real de cocina por mes: inventarios y compras que se escriben en el informe mensual.
--   inventario_inicial: solo si se quiere fijar a mano; si está vacío se usa el inventario_final del mes anterior.
-- Solo crea una tabla nueva. Se puede correr más de una vez.
create table if not exists public.foodcost_cocina (
  location_id uuid not null references public.locations(id),
  mes date not null,                       -- primer día del mes
  inventario_inicial numeric,
  compras numeric,
  inventario_final numeric,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (location_id, mes)
);

alter table public.foodcost_cocina enable row level security;
drop policy if exists foodcost_cocina_select on public.foodcost_cocina;
drop policy if exists foodcost_cocina_insert on public.foodcost_cocina;
drop policy if exists foodcost_cocina_update on public.foodcost_cocina;
create policy foodcost_cocina_select on public.foodcost_cocina
  for select using (public.has_location_access(location_id) or public.is_eventos_user());
create policy foodcost_cocina_insert on public.foodcost_cocina
  for insert with check (public.is_admin() and (public.has_location_access(location_id) or public.is_eventos_user()));
create policy foodcost_cocina_update on public.foodcost_cocina
  for update using (public.is_admin() and (public.has_location_access(location_id) or public.is_eventos_user()));

notify pgrst, 'reload schema';
