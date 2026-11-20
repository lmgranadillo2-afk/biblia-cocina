-- Lista de montaje de un evento: equipos, utensilios e insumos para ir marcando "listo".
-- Decisiones de Miguel (20 nov 2026):
--   * Agregan, editan y quitan ítems: el super admin y el usuario de Eventos (seguimiento_puede_editar()).
--   * Marcan "listo" y dejan notas: todos los que ven el evento, SOLO con las funciones de abajo.
--   * El costo de los alquileres lo ven solo los admin (tabla aparte); no suma a la cotización.
--   * Se pueden guardar listas como plantilla para reutilizarlas.
-- Necesita sql/eventos_solo_lectura.sql corrido antes. No borra datos. Se puede correr más de una vez.

-- 1) Ítems de la lista
create table if not exists public.evento_lista (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references public.costeo_eventos(id) on delete cascade,
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
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists evento_lista_evento_idx on public.evento_lista (evento_id);
alter table public.evento_lista enable row level security;

-- Lo ve quien ve el evento (la regla de lectura de costeo_eventos se aplica dentro del exists).
drop policy if exists evento_lista_ver on public.evento_lista;
drop policy if exists evento_lista_crear on public.evento_lista;
drop policy if exists evento_lista_editar on public.evento_lista;
drop policy if exists evento_lista_borrar on public.evento_lista;
create policy evento_lista_ver on public.evento_lista for select to authenticated
  using (exists (select 1 from public.costeo_eventos e where e.id = evento_id));
create policy evento_lista_crear on public.evento_lista for insert to authenticated
  with check (public.seguimiento_puede_editar());
create policy evento_lista_editar on public.evento_lista for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());
create policy evento_lista_borrar on public.evento_lista for delete to authenticated
  using (public.seguimiento_puede_editar());

-- 2) Costo de los alquileres: solo admin (lo ven y ponen admin, super admin y el usuario de Eventos).
create table if not exists public.evento_lista_costos (
  item_id uuid primary key references public.evento_lista(id) on delete cascade,
  evento_id uuid not null references public.costeo_eventos(id) on delete cascade,
  costo numeric not null default 0
);
create index if not exists evento_lista_costos_evento_idx on public.evento_lista_costos (evento_id);
alter table public.evento_lista_costos enable row level security;

drop policy if exists evento_lista_costos_ver on public.evento_lista_costos;
drop policy if exists evento_lista_costos_escribir on public.evento_lista_costos;
create policy evento_lista_costos_ver on public.evento_lista_costos for select to authenticated
  using ((public.is_admin() or public.seguimiento_puede_editar())
         and exists (select 1 from public.costeo_eventos e where e.id = evento_id));
create policy evento_lista_costos_escribir on public.evento_lista_costos for all to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());

-- 3) Plantillas de lista (solo las usan quienes arman listas)
create table if not exists public.evento_lista_plantillas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  items jsonb not null default '[]'::jsonb,   -- [{categoria, nombre, cantidad, responsable, alquiler, proveedor, costo}]
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.evento_lista_plantillas enable row level security;
drop policy if exists evento_lista_plantillas_todo on public.evento_lista_plantillas;
create policy evento_lista_plantillas_todo on public.evento_lista_plantillas for all to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());

-- 4) Marcar listo y dejar nota: cualquiera que vea el evento, y nada más que eso.
create or replace function public.evento_lista_puede_ver(p_evento uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.costeo_eventos e
    where e.id = p_evento
      and (public.is_eventos_user() or public.has_location_access(e.restaurante_id) or public.is_super_admin())
  );
$$;
revoke execute on function public.evento_lista_puede_ver(uuid) from public, anon;
grant execute on function public.evento_lista_puede_ver(uuid) to authenticated, service_role;

create or replace function public.evento_lista_marcar(p_item uuid, p_listo boolean)
returns public.evento_lista language plpgsql security definer set search_path = public as $$
declare
  r public.evento_lista;
  quien text;
begin
  select * into r from public.evento_lista where id = p_item;
  if not found then raise exception 'Ese ítem ya no existe'; end if;
  if not public.evento_lista_puede_ver(r.evento_id) then raise exception 'No tienes acceso a este evento'; end if;
  select coalesce(nullif(name, ''), (select email from auth.users where id = auth.uid())) into quien
    from public.profiles where id = auth.uid();
  update public.evento_lista
     set listo_por = case when p_listo then quien end,
         listo_at  = case when p_listo then now() end
   where id = p_item
   returning * into r;
  return r;
end $$;
revoke execute on function public.evento_lista_marcar(uuid, boolean) from public, anon;
grant execute on function public.evento_lista_marcar(uuid, boolean) to authenticated, service_role;

create or replace function public.evento_lista_nota(p_item uuid, p_nota text)
returns public.evento_lista language plpgsql security definer set search_path = public as $$
declare
  r public.evento_lista;
  quien text;
  t text := nullif(btrim(coalesce(p_nota, '')), '');
begin
  select * into r from public.evento_lista where id = p_item;
  if not found then raise exception 'Ese ítem ya no existe'; end if;
  if not public.evento_lista_puede_ver(r.evento_id) then raise exception 'No tienes acceso a este evento'; end if;
  if t is not null and length(t) > 300 then raise exception 'La nota es muy larga (máximo 300 letras)'; end if;
  select coalesce(nullif(name, ''), (select email from auth.users where id = auth.uid())) into quien
    from public.profiles where id = auth.uid();
  update public.evento_lista
     set nota = t, nota_por = case when t is null then null else quien end, nota_at = case when t is null then null else now() end
   where id = p_item
   returning * into r;
  return r;
end $$;
revoke execute on function public.evento_lista_nota(uuid, text) from public, anon;
grant execute on function public.evento_lista_nota(uuid, text) to authenticated, service_role;

-- 5) Tiempo real: lo que marca una persona les aparece a las demás.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'evento_lista') then
    alter publication supabase_realtime add table public.evento_lista;
  end if;
end $$;

notify pgrst, 'reload schema';

-- Revisión: deben salir las 3 tablas.
select tablename from pg_tables where schemaname = 'public' and tablename like 'evento_lista%' order by 1;
