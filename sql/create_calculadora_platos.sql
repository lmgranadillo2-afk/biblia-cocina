-- Se puede correr más de una vez (si ya lo corriste, solo agrega lo que falte).
-- 1) Módulo "Calculadora de precios": tabla nueva, solo el super admin puede ver y modificar.
create table if not exists public.calculadora_platos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  costo_base numeric not null default 0,
  items jsonb not null default '[]'::jsonb,   -- [{nombre, valor, tipo: 'fijo'|'pct'}], pct = % del costo base
  margen_pct numeric not null default 30,     -- % del precio de venta que es ganancia
  costo_total numeric not null default 0,
  precio numeric not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ICO (% sobre la venta sin ICO); se agrega aparte por si la tabla ya existía.
alter table public.calculadora_platos add column if not exists ico_pct numeric not null default 8;

alter table public.calculadora_platos enable row level security;
drop policy if exists calculadora_platos_super on public.calculadora_platos;
create policy calculadora_platos_super on public.calculadora_platos
  for all using (public.is_super_admin()) with check (public.is_super_admin());

-- 2) Seguridad: hoy cualquier admin puede editar perfiles, incluida la marca de super admin.
--    Este disparador impide que alguien que NO es super admin cambie is_super_admin (de nadie, ni el suyo).
--    Los admins siguen pudiendo cambiar el rol admin/cocina como hasta ahora.
create or replace function public.proteger_super_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_super_admin is distinct from old.is_super_admin
     and auth.uid() is not null
     and not public.is_super_admin() then
    raise exception 'Solo un super admin puede cambiar quién es super admin';
  end if;
  return new;
end $$;

drop trigger if exists proteger_super_admin on public.profiles;
create trigger proteger_super_admin before update on public.profiles
  for each row execute function public.proteger_super_admin();

notify pgrst, 'reload schema';
