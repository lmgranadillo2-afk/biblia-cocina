-- Punto "Eventos": central comercial que cotiza eventos de todos los restaurantes.
-- Correr UNA vez, completo. No borra datos: crea el punto, su área, copia los cargos
-- de Cantina Dos Santos, mueve los eventos existentes y ajusta permisos (RLS).

-- 1) Punto Eventos (mismos colores y logo que Cantina Dos Santos) y su área "Comercial" solo con Costeo.
insert into public.locations (slug, name, logo_data_url, color_bg, color_accent, color_accent_2, activo)
select 'eventos', 'Eventos', logo_data_url, color_bg, color_accent, color_accent_2, true
from public.locations
where slug = 'dos-santos'
  and not exists (select 1 from public.locations where slug = 'eventos');

insert into public.areas (location_id, name, modules)
select l.id, 'Comercial', '["costeo"]'::jsonb
from public.locations l
where l.slug = 'eventos'
  and not exists (select 1 from public.areas a where a.location_id = l.id);

-- Acceso para chef@cantinadossantos.com (los demás se asignan en Admin → Usuarios).
insert into public.user_locations (user_id, location_id)
select u.id, l.id
from auth.users u, public.locations l
where u.email = 'chef@cantinadossantos.com' and l.slug = 'eventos'
  and not exists (select 1 from public.user_locations ul where ul.user_id = u.id and ul.location_id = l.id);

insert into public.user_areas (user_id, area_id)
select u.id, a.id
from auth.users u
join public.locations l on l.slug = 'eventos'
join public.areas a on a.location_id = l.id
where u.email = 'chef@cantinadossantos.com'
  and not exists (select 1 from public.user_areas ua where ua.user_id = u.id and ua.area_id = a.id);

-- 2) Cargos de Eventos: copia de los cargos de Cantina Dos Santos (se editan en Eventos → Costeo → Cargos).
insert into public.costeo_cargos (location_id, nombre, tipo, salario_mensual, factor_prestacional_pct, incluye_auxilio_transporte, horas_mes, valor_hora, created_by)
select ev.id, c.nombre, c.tipo, c.salario_mensual, c.factor_prestacional_pct, c.incluye_auxilio_transporte, c.horas_mes, c.valor_hora, c.created_by
from public.costeo_cargos c
join public.locations ds on ds.id = c.location_id and ds.slug = 'dos-santos'
cross join public.locations ev
where ev.slug = 'eventos'
  and not exists (select 1 from public.costeo_cargos x where x.location_id = ev.id);

-- 3) Cada evento sabe en qué restaurante se hace. location_id pasa a ser "dónde se creó".
alter table public.costeo_eventos
  add column if not exists restaurante_id uuid references public.locations(id);

update public.costeo_eventos set restaurante_id = location_id where restaurante_id is null;

update public.costeo_eventos e
set location_id = l.id
from public.locations l
where l.slug = 'eventos'
  and e.location_id = e.restaurante_id;

-- 4) Permisos. Quien tenga acceso al punto Eventos ve todos los eventos, la carta y los datos
--    básicos de todos los restaurantes; cada restaurante ve los eventos que se hacen en él.
create or replace function public.eventos_location_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.locations where slug = 'eventos' limit 1;
$$;

create or replace function public.is_eventos_user()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.has_location_access(public.eventos_location_id()), false);
$$;

drop policy if exists costeo_eventos_select on public.costeo_eventos;
drop policy if exists costeo_eventos_insert on public.costeo_eventos;
drop policy if exists costeo_eventos_update on public.costeo_eventos;
drop policy if exists costeo_eventos_delete on public.costeo_eventos;

create policy costeo_eventos_select on public.costeo_eventos
  for select using (public.is_eventos_user() or public.has_location_access(restaurante_id));
create policy costeo_eventos_insert on public.costeo_eventos
  for insert with check (public.is_eventos_user() or public.has_location_access(restaurante_id));
create policy costeo_eventos_update on public.costeo_eventos
  for update using (public.is_eventos_user() or public.has_location_access(restaurante_id));
create policy costeo_eventos_delete on public.costeo_eventos
  for delete using (public.is_eventos_user() or public.has_location_access(restaurante_id));

-- Carta: Eventos la lee de todos los restaurantes; un admin de Eventos también la puede editar.
create policy carta_items_select_eventos on public.carta_items
  for select using (public.is_eventos_user());
create policy carta_items_insert_eventos on public.carta_items
  for insert with check (public.is_admin() and public.is_eventos_user());
create policy carta_items_update_eventos on public.carta_items
  for update using (public.is_admin() and public.is_eventos_user());
create policy carta_items_delete_eventos on public.carta_items
  for delete using (public.is_admin() and public.is_eventos_user());

-- Cargos del punto Eventos: visibles para cualquier usuario con sesión (los restaurantes los usan
-- al cotizar eventos desde su propia pestaña). Solo se editan desde Eventos (políticas existentes).
create policy costeo_cargos_select_eventos on public.costeo_cargos
  for select to authenticated
  using (location_id = public.eventos_location_id());

-- Nombre, slug y colores de los restaurantes, para el selector "Restaurante del evento".
create policy locations_select_eventos on public.locations
  for select using (public.is_eventos_user());
