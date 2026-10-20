-- Bajas separadas por ÁREA (antes solo por punto: el admin veía las de Cocina, Barra y Servicio mezcladas).
-- 1) Agrega area_id. 2) Asigna las bajas existentes según quién las registró. 3) Ajusta los permisos (RLS).
-- No borra ninguna baja. Se puede correr más de una vez.
-- ORDEN: correr este script ANTES de subir la app nueva.

-- 1) Columna de área
alter table public.bajas add column if not exists area_id uuid references public.areas(id) on delete set null;
create index if not exists bajas_area_idx on public.bajas(area_id);

-- 2) Bajas existentes: si quien la registró tiene UNA sola área en ese punto, va a esa área.
--    Si tiene varias (o ninguna), queda sin área: solo la ve un admin del punto en Admin → Bajas.
update public.bajas b
set area_id = x.area_id
from (
  select b2.id, (array_agg(a.id))[1] as area_id
  from public.bajas b2
  join public.user_areas ua on ua.user_id = b2.created_by
  join public.areas a on a.id = ua.area_id and a.location_id = b2.location_id
  where b2.area_id is null
  group by b2.id
  having count(*) = 1
) x
where b.id = x.id;

-- 3) Permisos
-- Ver: quien la registró o un admin, con acceso al punto y al área (las sin área: solo admin o quien la registró).
drop policy if exists "acceso por punto ve bajas" on public.bajas;
drop policy if exists "acceso por area ve bajas" on public.bajas;
create policy "acceso por area ve bajas" on public.bajas
  for select using (
    ((created_by = auth.uid()) or public.is_admin())
    and public.has_location_access(location_id)
    and (area_id is null or public.has_area_access(area_id))
  );

-- Crear: siempre con un área del mismo punto a la que el usuario tenga acceso.
drop policy if exists "acceso por punto crea bajas" on public.bajas;
drop policy if exists "acceso por area crea bajas" on public.bajas;
create policy "acceso por area crea bajas" on public.bajas
  for insert with check (
    auth.uid() is not null
    and public.has_location_access(location_id)
    and area_id is not null
    and public.has_area_access(area_id)
    and exists (select 1 from public.areas a where a.id = area_id and a.location_id = bajas.location_id)
  );

-- Resolver (ingresar / denegar): admin con acceso al punto y al área de la baja.
drop policy if exists "admin del punto resuelve bajas" on public.bajas;
drop policy if exists "admin del area resuelve bajas" on public.bajas;
create policy "admin del area resuelve bajas" on public.bajas
  for update
  using (public.is_admin() and public.has_location_access(location_id) and (area_id is null or public.has_area_access(area_id)))
  with check (public.is_admin() and public.has_location_access(location_id) and (area_id is null or public.has_area_access(area_id)));

notify pgrst, 'reload schema';

-- Resultado: bajas por punto y área (las "sin área" las ve solo el admin del punto)
select l.name as punto, coalesce(a.name, '(sin área)') as area, count(*) as bajas
from public.bajas b
join public.locations l on l.id = b.location_id
left join public.areas a on a.id = b.area_id
group by l.name, a.name
order by l.name, a.name nulls last;
