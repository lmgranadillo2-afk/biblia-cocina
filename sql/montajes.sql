-- Montajes: listas de equipos, utensilios, insumos y producciones para ir marcando "listo".
-- Módulo aparte: NO tiene nada que ver con Eventos (decisión de Miguel, 20 nov 2026).
--   * Cada montaje es de un punto. Lo ven y marcan "listo" / dejan notas todos los del punto.
--   * Crean montajes, editan sus listas y usan plantillas: el super admin y el usuario de Eventos
--     (seguimiento_puede_editar(), de sql/eventos_solo_lectura.sql).
--   * El costo de los alquileres lo ven solo los admin y quienes editan.
-- Reemplaza la "lista de montaje" dentro de los eventos (sql/eventos_lista_montaje.sql): esas tablas
-- quedan sin uso y no se borran aquí. No borra datos. Se puede correr más de una vez.

-- 1) Montajes
create table if not exists public.montajes (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  nombre text not null,
  fecha date,
  lugar text,
  notas text,
  estado text not null default 'abierto' check (estado in ('abierto', 'cerrado')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists montajes_location_idx on public.montajes (location_id);
alter table public.montajes enable row level security;

create or replace function public.montaje_puede_ver(p_montaje uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.montajes m
    where m.id = p_montaje
      and (public.has_location_access(m.location_id) or public.seguimiento_puede_editar())
  );
$$;
revoke execute on function public.montaje_puede_ver(uuid) from public, anon;
grant execute on function public.montaje_puede_ver(uuid) to authenticated, service_role;

drop policy if exists montajes_ver on public.montajes;
drop policy if exists montajes_crear on public.montajes;
drop policy if exists montajes_editar on public.montajes;
drop policy if exists montajes_borrar on public.montajes;
create policy montajes_ver on public.montajes for select to authenticated
  using (public.has_location_access(location_id) or public.seguimiento_puede_editar());
create policy montajes_crear on public.montajes for insert to authenticated
  with check (public.seguimiento_puede_editar());
create policy montajes_editar on public.montajes for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());
create policy montajes_borrar on public.montajes for delete to authenticated
  using (public.seguimiento_puede_editar());

-- 2) Ítems de la lista
create table if not exists public.montaje_items (
  id uuid primary key default gen_random_uuid(),
  montaje_id uuid not null references public.montajes(id) on delete cascade,
  categoria text not null default 'Equipos',
  nombre text not null,
  cantidad text,
  responsable text,
  alquiler boolean not null default false,
  proveedor text,
  orden int not null default 0,
  listo_por text,
  listo_at timestamptz,
  nota text,
  nota_por text,
  nota_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists montaje_items_montaje_idx on public.montaje_items (montaje_id);
alter table public.montaje_items enable row level security;

drop policy if exists montaje_items_ver on public.montaje_items;
drop policy if exists montaje_items_crear on public.montaje_items;
drop policy if exists montaje_items_editar on public.montaje_items;
drop policy if exists montaje_items_borrar on public.montaje_items;
create policy montaje_items_ver on public.montaje_items for select to authenticated
  using (exists (select 1 from public.montajes m where m.id = montaje_id));
create policy montaje_items_crear on public.montaje_items for insert to authenticated
  with check (public.seguimiento_puede_editar());
create policy montaje_items_editar on public.montaje_items for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());
create policy montaje_items_borrar on public.montaje_items for delete to authenticated
  using (public.seguimiento_puede_editar());

-- 3) Costo de los alquileres (solo admin y quienes editan)
create table if not exists public.montaje_costos (
  item_id uuid primary key references public.montaje_items(id) on delete cascade,
  montaje_id uuid not null references public.montajes(id) on delete cascade,
  costo numeric not null default 0
);
create index if not exists montaje_costos_montaje_idx on public.montaje_costos (montaje_id);
alter table public.montaje_costos enable row level security;

drop policy if exists montaje_costos_ver on public.montaje_costos;
drop policy if exists montaje_costos_escribir on public.montaje_costos;
create policy montaje_costos_ver on public.montaje_costos for select to authenticated
  using ((public.is_admin() or public.seguimiento_puede_editar())
         and exists (select 1 from public.montajes m where m.id = montaje_id));
create policy montaje_costos_escribir on public.montaje_costos for all to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());

-- 4) Plantillas
create table if not exists public.montaje_plantillas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  items jsonb not null default '[]'::jsonb,   -- [{categoria, nombre, cantidad, responsable, alquiler, proveedor, costo}]
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.montaje_plantillas enable row level security;
drop policy if exists montaje_plantillas_todo on public.montaje_plantillas;
create policy montaje_plantillas_todo on public.montaje_plantillas for all to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());

-- 5) Marcar listo y dejar nota: todos los que ven el montaje, y nada más que eso.
create or replace function public.montaje_marcar(p_item uuid, p_listo boolean)
returns public.montaje_items language plpgsql security definer set search_path = public as $$
declare
  r public.montaje_items;
  quien text;
begin
  select * into r from public.montaje_items where id = p_item;
  if not found then raise exception 'Ese ítem ya no existe'; end if;
  if not public.montaje_puede_ver(r.montaje_id) then raise exception 'No tienes acceso a este montaje'; end if;
  select coalesce(nullif(p.name, ''), u.email) into quien
    from auth.users u left join public.profiles p on p.id = u.id where u.id = auth.uid();
  update public.montaje_items
     set listo_por = case when p_listo then quien end,
         listo_at  = case when p_listo then now() end
   where id = p_item
   returning * into r;
  return r;
end $$;
revoke execute on function public.montaje_marcar(uuid, boolean) from public, anon;
grant execute on function public.montaje_marcar(uuid, boolean) to authenticated, service_role;

create or replace function public.montaje_nota(p_item uuid, p_nota text)
returns public.montaje_items language plpgsql security definer set search_path = public as $$
declare
  r public.montaje_items;
  quien text;
  t text := nullif(btrim(coalesce(p_nota, '')), '');
begin
  select * into r from public.montaje_items where id = p_item;
  if not found then raise exception 'Ese ítem ya no existe'; end if;
  if not public.montaje_puede_ver(r.montaje_id) then raise exception 'No tienes acceso a este montaje'; end if;
  if t is not null and length(t) > 300 then raise exception 'La nota es muy larga (máximo 300 letras)'; end if;
  select coalesce(nullif(p.name, ''), u.email) into quien
    from auth.users u left join public.profiles p on p.id = u.id where u.id = auth.uid();
  update public.montaje_items
     set nota = t,
         nota_por = case when t is null then null else quien end,
         nota_at  = case when t is null then null else now() end
   where id = p_item
   returning * into r;
  return r;
end $$;
revoke execute on function public.montaje_nota(uuid, text) from public, anon;
grant execute on function public.montaje_nota(uuid, text) to authenticated, service_role;

-- 6) Tiempo real: lo que marca una persona les aparece a las demás.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'montaje_items') then
    alter publication supabase_realtime add table public.montaje_items;
  end if;
end $$;

notify pgrst, 'reload schema';

-- Revisión: deben salir montaje_costos, montaje_items, montaje_plantillas y montajes.
select tablename from pg_tables where schemaname = 'public' and tablename like 'montaje%' order by 1;
