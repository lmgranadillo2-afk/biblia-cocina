-- Módulo Shows (decisiones de Miguel, 5 nov 2026): programación de shows de Cantina Dos Santos Medellín.
-- Solo gerencia@cantinadossantos.com (profiles.es_shows) y los super admin. Catálogo de grupos con precio entre semana
-- (lun–jue) y fin de semana (vie–dom); franjas editables (arranca con 9:30, 10:00 y 11:00); un día se puede cancelar
-- (queda en rojo y no suma). Arranca vacío. No borra datos; se puede correr más de una vez.
alter table public.profiles add column if not exists es_shows boolean not null default false;
update public.profiles p set es_shows = true from auth.users u where u.id = p.id and lower(u.email) = 'gerencia@cantinadossantos.com';

create or replace function public.puede_shows()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin() or coalesce((select es_shows from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.puede_shows() from public, anon;
grant execute on function public.puede_shows() to authenticated, service_role;

create table if not exists public.shows_grupos (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete cascade,
  nombre text not null check (btrim(nombre) <> ''),
  precio_semana numeric not null default 0 check (precio_semana >= 0),
  precio_finde numeric not null default 0 check (precio_finde >= 0),
  activo boolean not null default true,
  orden int not null default 100
);
create unique index if not exists shows_grupos_nombre_idx on public.shows_grupos (location_id, lower(btrim(nombre)));

create table if not exists public.shows_franjas (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete cascade,
  hora time not null,
  activa boolean not null default true
);
create unique index if not exists shows_franjas_hora_idx on public.shows_franjas (location_id, hora);

create table if not exists public.shows_dias (
  location_id uuid not null references public.locations(id) on delete cascade,
  fecha date not null,
  tipo text check (tipo is null or tipo in ('Mariachis', 'Banda', 'Otro')),
  cancelado boolean not null default false,
  nota text,
  primary key (location_id, fecha)
);

create table if not exists public.shows_asignaciones (
  location_id uuid not null references public.locations(id) on delete cascade,
  fecha date not null,
  franja_id uuid not null references public.shows_franjas(id),
  grupo_id uuid not null references public.shows_grupos(id),
  valor numeric not null default 0 check (valor >= 0),
  actualizado_por text,
  updated_at timestamptz not null default now(),
  primary key (location_id, fecha, franja_id)
);

do $$
declare t text;
begin
  foreach t in array array['shows_grupos', 'shows_franjas', 'shows_dias', 'shows_asignaciones'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists shows_todo on public.%I', t);
    execute format('create policy shows_todo on public.%I for all to authenticated using (public.puede_shows()) with check (public.puede_shows())', t);
  end loop;
end $$;

create or replace function public.shows_quien()
returns trigger language plpgsql security definer set search_path = public as $$
begin new.actualizado_por := public.nombre_usuario_actual(); new.updated_at := now(); return new; end;
$$;
drop trigger if exists shows_asignaciones_quien on public.shows_asignaciones;
create trigger shows_asignaciones_quien before insert or update on public.shows_asignaciones for each row execute function public.shows_quien();

-- Catálogo y franjas iniciales de Cantina Dos Santos (precios de la hoja de junio; se editan en la app).
insert into public.shows_franjas (location_id, hora)
select 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b', h::time from unnest(array['21:30', '22:00', '23:00']) h
on conflict (location_id, hora) do nothing;
insert into public.shows_grupos (location_id, nombre, precio_semana, precio_finde, orden) values
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Sentimiento', 600000, 650000, 1),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Real', 600000, 650000, 2),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Álamo', 600000, 650000, 3),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Hernández', 650000, 650000, 4),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Mateo Bedoya', 600000, 900000, 5),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'MA', 1300000, 1300000, 6),
  ('c98db3a9-7be7-4bf6-8b77-318e6ca3098b', 'Show de fuego', 200000, 200000, 7)
on conflict (location_id, lower(btrim(nombre))) do nothing;

notify pgrst, 'reload schema';

-- Debe mostrar 7 grupos y 3 franjas
select (select count(*) from public.shows_grupos) grupos, (select count(*) from public.shows_franjas) franjas;
