-- Módulo Horarios — paso 5: pre-nómina (horas para el contador). Correr después de horarios_1 a 4.
-- No borra datos. Se puede correr más de una vez.
--
-- Decisiones de Miguel (23 oct 2026, con su contador externo):
--  * Horas extra por SEMANA: lo que pase de la jornada máxima (42 h) de lunes a domingo.
--  * Domingo como día ordinario (jornada flexible pactada, Art. 161 lit. d) → recargo dominical 0 % por defecto.
--    Festivos con recargo (90 % desde jul 2026, Ley 2466 de 2025). Todo editable en Pre-nómina → Parámetros.
--  * Salarios cargados en la app: SOLO los ven y editan los admin (no los líderes de horarios).

-- 1) Parámetros de la pre-nómina por área
alter table public.horario_config
  add column if not exists recargo_nocturno numeric(5,2) not null default 35,
  add column if not exists extra_diurna numeric(5,2) not null default 25,
  add column if not exists extra_nocturna numeric(5,2) not null default 75,
  add column if not exists recargo_dominical numeric(5,2) not null default 0,
  add column if not exists recargo_festivo numeric(5,2) not null default 90,
  add column if not exists horas_mes numeric(6,2) not null default 180,
  add column if not exists nota_dominical text not null default 'Domingo como día ordinario: jornada flexible pactada (Art. 161 lit. d CST).';

-- 2) Permiso remunerado o no
alter table public.horario_novedades add column if not exists remunerado boolean;

-- 3) Salarios: solo admin con acceso al área
create table if not exists public.horario_salarios (
  personal_id uuid primary key references public.horario_personal(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete cascade,
  salario numeric(12,0) not null check (salario >= 0),
  actualizado_por text,
  updated_at timestamptz not null default now()
);
alter table public.horario_salarios enable row level security;
drop policy if exists horario_salarios_ver on public.horario_salarios;
drop policy if exists horario_salarios_crear on public.horario_salarios;
drop policy if exists horario_salarios_editar on public.horario_salarios;
drop policy if exists horario_salarios_borrar on public.horario_salarios;
create policy horario_salarios_ver on public.horario_salarios for select to authenticated
  using ((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id));
create policy horario_salarios_crear on public.horario_salarios for insert to authenticated
  with check ((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id));
create policy horario_salarios_editar on public.horario_salarios for update to authenticated
  using ((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id))
  with check ((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id));
create policy horario_salarios_borrar on public.horario_salarios for delete to authenticated
  using ((public.is_admin() or public.is_super_admin()) and public.has_area_access(area_id));

-- 4) Festivos de Colombia (Ley Emiliani: los trasladables pasan al lunes siguiente). Los ve cualquiera con sesión.
create table if not exists public.horario_festivos (
  fecha date primary key,
  nombre text not null
);
alter table public.horario_festivos enable row level security;
drop policy if exists horario_festivos_ver on public.horario_festivos;
create policy horario_festivos_ver on public.horario_festivos for select to authenticated using (true);

insert into public.horario_festivos (fecha, nombre) values
  ('2026-01-01', 'Año Nuevo'),
  ('2026-01-12', 'Reyes Magos'),
  ('2026-03-23', 'San José'),
  ('2026-04-02', 'Jueves Santo'),
  ('2026-04-03', 'Viernes Santo'),
  ('2026-05-01', 'Día del Trabajo'),
  ('2026-05-18', 'Ascensión del Señor'),
  ('2026-06-08', 'Corpus Christi'),
  ('2026-06-15', 'Sagrado Corazón'),
  ('2026-06-29', 'San Pedro y San Pablo'),
  ('2026-07-20', 'Independencia de Colombia'),
  ('2026-08-07', 'Batalla de Boyacá'),
  ('2026-08-17', 'Asunción de la Virgen'),
  ('2026-10-12', 'Día de la Raza'),
  ('2026-11-02', 'Todos los Santos'),
  ('2026-11-16', 'Independencia de Cartagena'),
  ('2026-12-08', 'Inmaculada Concepción'),
  ('2026-12-25', 'Navidad'),
  ('2027-01-01', 'Año Nuevo'),
  ('2027-01-11', 'Reyes Magos'),
  ('2027-03-22', 'San José'),
  ('2027-03-25', 'Jueves Santo'),
  ('2027-03-26', 'Viernes Santo'),
  ('2027-05-01', 'Día del Trabajo'),
  ('2027-05-10', 'Ascensión del Señor'),
  ('2027-05-31', 'Corpus Christi'),
  ('2027-06-07', 'Sagrado Corazón'),
  ('2027-07-05', 'San Pedro y San Pablo'),
  ('2027-07-20', 'Independencia de Colombia'),
  ('2027-08-07', 'Batalla de Boyacá'),
  ('2027-08-16', 'Asunción de la Virgen'),
  ('2027-10-18', 'Día de la Raza'),
  ('2027-11-01', 'Todos los Santos'),
  ('2027-11-15', 'Independencia de Cartagena'),
  ('2027-12-08', 'Inmaculada Concepción'),
  ('2027-12-25', 'Navidad')
on conflict (fecha) do nothing;

notify pgrst, 'reload schema';

-- Debe mostrar: 36 festivos, la tabla de salarios con RLS activo (true) y el recargo dominical en 0
select
  (select count(*) from public.horario_festivos) as festivos,
  (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'horario_salarios') as salarios_rls,
  (select max(recargo_dominical) from public.horario_config) as recargo_dominical;
