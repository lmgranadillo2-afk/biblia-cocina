-- Punto "Admin": central de gerencia con todo el Costeo de todos los restaurantes
-- (eventos, cartas y Toteat, cargos de eventos y food cost).
-- Correr UNA vez. No borra ni modifica datos existentes.

-- 1) Punto y área (mismos colores y logo que Cantina Dos Santos).
insert into public.locations (slug, name, logo_data_url, color_bg, color_accent, color_accent_2, activo)
select 'admin', 'Admin', logo_data_url, color_bg, color_accent, color_accent_2, true
from public.locations
where slug = 'dos-santos'
  and not exists (select 1 from public.locations where slug = 'admin');

insert into public.areas (location_id, name, modules)
select l.id, 'Gerencia', '["costeo"]'::jsonb
from public.locations l
where l.slug = 'admin'
  and not exists (select 1 from public.areas a where a.location_id = l.id);

-- Acceso para chef@cantinadossantos.com (los demás se asignan en Admin → Usuarios).
insert into public.user_locations (user_id, location_id)
select u.id, l.id
from auth.users u, public.locations l
where u.email = 'chef@cantinadossantos.com' and l.slug = 'admin'
  and not exists (select 1 from public.user_locations ul where ul.user_id = u.id and ul.location_id = l.id);

insert into public.user_areas (user_id, area_id)
select u.id, a.id
from auth.users u
join public.locations l on l.slug = 'admin'
join public.areas a on a.location_id = l.id
where u.email = 'chef@cantinadossantos.com'
  and not exists (select 1 from public.user_areas ua where ua.user_id = u.id and ua.area_id = a.id);

-- 2) Quien tenga acceso a Eventos O a Admin ve eventos, cartas y datos de todos los restaurantes
--    (todas las políticas que usan is_eventos_user() pasan a incluir Admin).
create or replace function public.admin_location_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.locations where slug = 'admin' limit 1;
$$;

create or replace function public.is_eventos_user()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.has_location_access(public.eventos_location_id()), false)
      or coalesce(public.has_location_access(public.admin_location_id()), false);
$$;

-- 3) Los cargos de eventos (guardados en el punto Eventos) se editan desde Admin.
drop policy if exists costeo_cargos_insert_hub on public.costeo_cargos;
drop policy if exists costeo_cargos_update_hub on public.costeo_cargos;
drop policy if exists costeo_cargos_delete_hub on public.costeo_cargos;
create policy costeo_cargos_insert_hub on public.costeo_cargos
  for insert with check (public.is_admin() and public.is_eventos_user() and location_id = public.eventos_location_id());
create policy costeo_cargos_update_hub on public.costeo_cargos
  for update using (public.is_admin() and public.is_eventos_user() and location_id = public.eventos_location_id());
create policy costeo_cargos_delete_hub on public.costeo_cargos
  for delete using (public.is_admin() and public.is_eventos_user() and location_id = public.eventos_location_id());
