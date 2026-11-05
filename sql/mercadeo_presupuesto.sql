-- Presupuesto de mercadeo por restaurante (pestaña Mercadeo). Decisiones de Miguel (5 nov 2026):
-- presupuesto mensual por restaurante y categoría + gastos reales; cada gasto va a un solo restaurante;
-- soporte (foto o PDF) opcional; se puede pasar del presupuesto (solo avisa); lo manejan los super admin
-- y quien tenga profiles.es_mercadeo (mercadeo@cantinadossantos.com), desde cualquier punto.
-- No borra datos; se puede correr más de una vez.

alter table public.profiles add column if not exists es_mercadeo boolean not null default false;
update public.profiles p set es_mercadeo = true
from auth.users u where u.id = p.id and lower(u.email) = 'mercadeo@cantinadossantos.com';

create or replace function public.es_mercadeo()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select es_mercadeo from public.profiles where id = auth.uid()), false);
$$;
create or replace function public.puede_mercadeo()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin() or public.es_mercadeo();
$$;
revoke execute on function public.es_mercadeo() from public, anon;
revoke execute on function public.puede_mercadeo() from public, anon;
grant execute on function public.es_mercadeo() to authenticated, service_role;
grant execute on function public.puede_mercadeo() to authenticated, service_role;

-- La cuenta de mercadeo no tiene accesos por punto: ve los puntos y áreas para poder entrar (como Facturas).
drop policy if exists mercadeo_ver_locations on public.locations;
create policy mercadeo_ver_locations on public.locations for select to authenticated using (public.es_mercadeo());
drop policy if exists mercadeo_ver_areas on public.areas;
create policy mercadeo_ver_areas on public.areas for select to authenticated using (public.es_mercadeo());

create table if not exists public.mercadeo_presupuestos (
  location_id uuid not null references public.locations(id) on delete cascade,
  mes date not null check (extract(day from mes) = 1),
  categoria text not null check (categoria in ('pauta', 'influencers', 'impresos', 'activaciones')),
  valor numeric not null default 0 check (valor >= 0),
  actualizado_por text,
  updated_at timestamptz not null default now(),
  primary key (location_id, mes, categoria)
);
create table if not exists public.mercadeo_gastos (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id) on delete cascade,
  fecha date not null,
  categoria text not null check (categoria in ('pauta', 'influencers', 'impresos', 'activaciones')),
  valor numeric not null check (valor > 0),
  detalle text,
  soporte_path text,
  creado_por text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists mercadeo_gastos_fecha_idx on public.mercadeo_gastos (fecha);

alter table public.mercadeo_presupuestos enable row level security;
alter table public.mercadeo_gastos enable row level security;
drop policy if exists mercadeo_presupuestos_todo on public.mercadeo_presupuestos;
create policy mercadeo_presupuestos_todo on public.mercadeo_presupuestos for all to authenticated
  using (public.puede_mercadeo()) with check (public.puede_mercadeo());
drop policy if exists mercadeo_gastos_todo on public.mercadeo_gastos;
create policy mercadeo_gastos_todo on public.mercadeo_gastos for all to authenticated
  using (public.puede_mercadeo()) with check (public.puede_mercadeo());

-- Quién: lo pone la base.
create or replace function public.mercadeo_quien()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'mercadeo_gastos' then
    if tg_op = 'INSERT' then new.creado_por := public.nombre_usuario_actual(); new.created_by := auth.uid(); end if;
  else
    new.actualizado_por := public.nombre_usuario_actual(); new.updated_at := now();
  end if;
  return new;
end;
$$;
drop trigger if exists mercadeo_gastos_quien on public.mercadeo_gastos;
create trigger mercadeo_gastos_quien before insert on public.mercadeo_gastos for each row execute function public.mercadeo_quien();
drop trigger if exists mercadeo_presupuestos_quien on public.mercadeo_presupuestos;
create trigger mercadeo_presupuestos_quien before insert or update on public.mercadeo_presupuestos for each row execute function public.mercadeo_quien();

-- Soportes: bucket privado (<restaurante>/<mes>/<archivo>), 10 MB.
insert into storage.buckets (id, name, public, file_size_limit) values ('mercadeo-soportes', 'mercadeo-soportes', false, 10485760)
on conflict (id) do nothing;
drop policy if exists "mercadeo soportes: ver" on storage.objects;
drop policy if exists "mercadeo soportes: subir" on storage.objects;
drop policy if exists "mercadeo soportes: borrar" on storage.objects;
create policy "mercadeo soportes: ver" on storage.objects for select to authenticated using (bucket_id = 'mercadeo-soportes' and public.puede_mercadeo());
create policy "mercadeo soportes: subir" on storage.objects for insert to authenticated with check (bucket_id = 'mercadeo-soportes' and public.puede_mercadeo());
create policy "mercadeo soportes: borrar" on storage.objects for delete to authenticated using (bucket_id = 'mercadeo-soportes' and public.puede_mercadeo());

notify pgrst, 'reload schema';

-- Debe mostrar las dos tablas vacías
select (select count(*) from public.mercadeo_presupuestos) presupuestos, (select count(*) from public.mercadeo_gastos) gastos;
