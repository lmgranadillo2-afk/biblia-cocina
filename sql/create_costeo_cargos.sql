-- Costeo — Mano de obra (paso 1)
-- 1) Tabla de cargos por PUNTO con su valor por hora (se usa en platos y, en el
--    paso 2, en eventos).
-- 2) Columnas nuevas en costeo_platos para calcular la mano de obra por tiempo
--    (cargo + minutos por porción). No borra ni modifica datos existentes:
--    mano_obra_fijo se conserva y se sigue usando cuando el plato no tiene cargo.

create table if not exists public.costeo_cargos (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  nombre text not null,
  -- 'nomina': valor hora = (salario_mensual * (1 + factor_prestacional_pct/100)
  --            + auxilio de transporte si aplica) / horas_mes
  -- 'por_hora': valor hora = valor_hora (personal extra, turnos pagados por hora)
  tipo text not null default 'nomina' check (tipo in ('nomina','por_hora')),
  salario_mensual numeric not null default 1750905, -- SMMLV 2026 (Decreto 1469 de 2025)
  factor_prestacional_pct numeric not null default 8,
  incluye_auxilio_transporte boolean not null default true,
  horas_mes numeric not null default 182,
  valor_hora numeric not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.costeo_cargos enable row level security;

-- Todos los que tienen acceso al punto ven los cargos (para poder costear);
-- solo admin los crea, edita o elimina.
create policy costeo_cargos_select on public.costeo_cargos
  for select using (public.has_location_access(location_id));

create policy costeo_cargos_insert on public.costeo_cargos
  for insert with check (public.is_admin() and public.has_location_access(location_id));

create policy costeo_cargos_update on public.costeo_cargos
  for update using (public.is_admin() and public.has_location_access(location_id));

create policy costeo_cargos_delete on public.costeo_cargos
  for delete using (public.is_admin() and public.has_location_access(location_id));

alter table public.costeo_platos
  add column if not exists mano_obra_cargo_id uuid references public.costeo_cargos(id) on delete set null,
  add column if not exists mano_obra_minutos numeric not null default 0;
