-- Módulo Horarios — paso 1: tablas, permisos (RLS) y funciones. Ver HORARIOS_SPEC.md.
-- No borra ni cambia datos existentes; solo agrega la columna lider_horarios a user_areas (en falso para todos).
-- Se puede correr más de una vez. Después correr horarios_2_datos_cocina_medellin.sql.
--
-- Días: 1 = lunes … 7 = domingo.
-- Quién edita: admin del área o usuario marcado como "Líder de horarios" en esa área (user_areas.lider_horarios).
-- El resto del área solo ve las semanas publicadas. Nada de esto se borra: personal, turnos, estaciones y tareas se desactivan.

-- 1) Líder de horarios por usuario y área
alter table public.user_areas add column if not exists lider_horarios boolean not null default false;

create or replace function public.horario_puede_editar(p_area uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.has_area_access(p_area) and (
    public.is_admin() or public.is_super_admin() or exists (
      select 1 from public.user_areas ua
      where ua.area_id = p_area and ua.user_id = auth.uid() and ua.lider_horarios)), false);
$$;
revoke execute on function public.horario_puede_editar(uuid) from public, anon;
grant execute on function public.horario_puede_editar(uuid) to authenticated, service_role;

-- Marcar / desmarcar líder: solo un admin con acceso al área, y la persona ya debe tener acceso a esa área.
create or replace function public.set_lider_horarios(p_user uuid, p_area uuid, p_valor boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not ((public.is_admin() or public.is_super_admin()) and public.has_area_access(p_area)) then
    raise exception 'Solo un admin del punto puede marcar líderes de horarios';
  end if;
  update public.user_areas set lider_horarios = p_valor where user_id = p_user and area_id = p_area;
  if not found then raise exception 'Primero dale acceso a esa área'; end if;
end;
$$;
revoke execute on function public.set_lider_horarios(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_lider_horarios(uuid, uuid, boolean) to authenticated, service_role;

-- 2) Configuración por área
create table if not exists public.horario_config (
  area_id uuid primary key references public.areas(id) on delete cascade,
  jornada_max numeric(4,1) not null default 42,          -- se avisa, no bloquea
  dias_sin_descanso smallint[] not null default '{5,6,7}', -- nadie descansa (salvo producción)
  updated_at timestamptz not null default now()
);

create table if not exists public.horario_estaciones (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  nombre text not null,
  color smallint not null default 1 check (color between 1 and 8),  -- paleta fija --est-1 … --est-8
  minimo_por_dia smallint[] not null default '{1,1,1,1,1,1,1}' check (array_length(minimo_por_dia, 1) = 7),
  orden int not null default 0,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  unique (area_id, nombre)
);

create table if not exists public.horario_personal (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  nombre text not null,
  estacion_id uuid references public.horario_estaciones(id) on delete set null,
  cargo text,
  descanso_dia smallint check (descanso_dia between 1 and 7),
  es_produccion boolean not null default false,
  activo boolean not null default true,
  user_id uuid references auth.users(id) on delete set null,
  orden int not null default 0,
  created_at timestamptz not null default now(),
  unique (area_id, nombre)
);

create table if not exists public.horario_turnos (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  codigo text not null,
  horas numeric(4,2) not null check (horas >= 0 and horas <= 24),
  cubre_manana boolean not null default false,
  cubre_cierre boolean not null default false,
  orden int not null default 0,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  unique (area_id, codigo)
);

-- Tareas diarias que se asignan a una persona por día (ej. Bunker = aseo del vestier). No suman horas.
create table if not exists public.horario_tareas (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  nombre text not null,
  detalle text,
  orden int not null default 0,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  unique (area_id, nombre)
);

-- 3) Semanas y asignaciones
create table if not exists public.horario_semanas (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  lunes date not null check (extract(isodow from lunes) = 1),
  estado text not null default 'borrador' check (estado in ('borrador', 'publicada')),
  publicada_por text,
  publicada_at timestamptz,
  ia_explicacion text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (area_id, lunes)
);

-- Una casilla por persona y día. codigo/horas se copian al guardar: si después cambian el turno, la semana no cambia.
create table if not exists public.horario_asignaciones (
  id uuid primary key default gen_random_uuid(),
  semana_id uuid not null references public.horario_semanas(id) on delete cascade,
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  dia smallint not null check (dia between 1 and 7),
  tipo text not null check (tipo in ('turno', 'descanso', 'otro')),
  turno_id uuid references public.horario_turnos(id) on delete set null,
  codigo text,                 -- "4-12" o, en "otro", "2-10"
  horas numeric(4,2) not null default 0 check (horas >= 0 and horas <= 24),
  cubre_manana boolean not null default false,
  cubre_cierre boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (semana_id, personal_id, dia)
);

create table if not exists public.horario_tarea_asignaciones (
  semana_id uuid not null references public.horario_semanas(id) on delete cascade,
  tarea_id uuid not null references public.horario_tareas(id) on delete cascade,
  dia smallint not null check (dia between 1 and 7),
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  primary key (semana_id, tarea_id, dia)
);

-- 4) Novedades y registro del día (la pantalla llega en la fase 2; las tablas quedan listas)
create table if not exists public.horario_novedades (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  tipo text not null check (tipo in ('incapacidad', 'vacaciones', 'permiso', 'vacante', 'retardo')),
  desde date not null,
  hasta date not null,
  nota text,
  creado_por text,
  created_at timestamptz not null default now(),
  check (hasta >= desde)
);

create table if not exists public.horario_registro_dia (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  fecha date not null,
  asistio boolean not null default true,
  horas_reales numeric(4,2) check (horas_reales >= 0 and horas_reales <= 24),
  nota text,
  cerrado_por text,
  cerrado_at timestamptz,
  unique (personal_id, fecha)
);

create index if not exists horario_asig_semana_idx on public.horario_asignaciones (semana_id);
create index if not exists horario_nov_area_idx on public.horario_novedades (area_id, desde, hasta);
create index if not exists horario_reg_area_idx on public.horario_registro_dia (area_id, fecha);

-- 5) Permisos de semanas (funciones propias para que las políticas no dependan unas de otras)
create or replace function public.horario_puede_ver_semana(p_semana uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.horario_semanas s
    where s.id = p_semana and public.has_area_access(s.area_id)
      and (s.estado = 'publicada' or public.horario_puede_editar(s.area_id)));
$$;
revoke execute on function public.horario_puede_ver_semana(uuid) from public, anon;
grant execute on function public.horario_puede_ver_semana(uuid) to authenticated, service_role;

create or replace function public.horario_puede_editar_semana(p_semana uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.horario_semanas s
    where s.id = p_semana and s.estado = 'borrador' and public.horario_puede_editar(s.area_id));
$$;
revoke execute on function public.horario_puede_editar_semana(uuid) from public, anon;
grant execute on function public.horario_puede_editar_semana(uuid) to authenticated, service_role;

-- 6) RLS
alter table public.horario_config enable row level security;
alter table public.horario_estaciones enable row level security;
alter table public.horario_personal enable row level security;
alter table public.horario_turnos enable row level security;
alter table public.horario_tareas enable row level security;
alter table public.horario_semanas enable row level security;
alter table public.horario_asignaciones enable row level security;
alter table public.horario_tarea_asignaciones enable row level security;
alter table public.horario_novedades enable row level security;
alter table public.horario_registro_dia enable row level security;

-- Configuración: la ve todo el área; la editan admin y líderes. Sin borrar (se desactiva).
do $$
declare t text;
begin
  foreach t in array array['horario_config', 'horario_estaciones', 'horario_personal', 'horario_turnos', 'horario_tareas'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_crear', t);
    execute format('drop policy if exists %I on public.%I', t || '_editar', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_area_access(area_id))', t || '_ver', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.horario_puede_editar(area_id))', t || '_crear', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.horario_puede_editar(area_id)) with check (public.horario_puede_editar(area_id))', t || '_editar', t);
  end loop;
end $$;

-- Novedades y registro: los ve el área; los manejan admin y líderes.
do $$
declare t text;
begin
  foreach t in array array['horario_novedades', 'horario_registro_dia'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_crear', t);
    execute format('drop policy if exists %I on public.%I', t || '_editar', t);
    execute format('drop policy if exists %I on public.%I', t || '_borrar', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_area_access(area_id))', t || '_ver', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.horario_puede_editar(area_id))', t || '_crear', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.horario_puede_editar(area_id)) with check (public.horario_puede_editar(area_id))', t || '_editar', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.horario_puede_editar(area_id))', t || '_borrar', t);
  end loop;
end $$;

-- Semanas: borradores solo los ven admin y líderes; publicar / volver a borrador solo con las funciones de abajo.
drop policy if exists horario_semanas_ver on public.horario_semanas;
drop policy if exists horario_semanas_crear on public.horario_semanas;
create policy horario_semanas_ver on public.horario_semanas for select to authenticated
  using (public.has_area_access(area_id) and (estado = 'publicada' or public.horario_puede_editar(area_id)));
create policy horario_semanas_crear on public.horario_semanas for insert to authenticated
  with check (public.horario_puede_editar(area_id) and estado = 'borrador' and publicada_at is null);

-- Casillas y tareas: se ven si se ve la semana; se editan solo con la semana en borrador.
do $$
declare t text;
begin
  foreach t in array array['horario_asignaciones', 'horario_tarea_asignaciones'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_crear', t);
    execute format('drop policy if exists %I on public.%I', t || '_editar', t);
    execute format('drop policy if exists %I on public.%I', t || '_borrar', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.horario_puede_ver_semana(semana_id))', t || '_ver', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.horario_puede_editar_semana(semana_id))', t || '_crear', t);
    execute format('create policy %I on public.%I for update to authenticated using (public.horario_puede_editar_semana(semana_id)) with check (public.horario_puede_editar_semana(semana_id))', t || '_editar', t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.horario_puede_editar_semana(semana_id))', t || '_borrar', t);
  end loop;
end $$;

-- 7) Publicar / volver a borrador
create or replace function public.horario_publicar(p_semana uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_area uuid;
begin
  select area_id into v_area from public.horario_semanas where id = p_semana;
  if v_area is null then raise exception 'No encontré la semana'; end if;
  if not public.horario_puede_editar(v_area) then raise exception 'Solo un admin o un líder de horarios puede publicar'; end if;
  update public.horario_semanas
  set estado = 'publicada', publicada_por = public.nombre_usuario_actual(), publicada_at = now()
  where id = p_semana;
end;
$$;
revoke execute on function public.horario_publicar(uuid) from public, anon;
grant execute on function public.horario_publicar(uuid) to authenticated, service_role;

create or replace function public.horario_volver_borrador(p_semana uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_area uuid;
begin
  select area_id into v_area from public.horario_semanas where id = p_semana;
  if v_area is null then raise exception 'No encontré la semana'; end if;
  if not public.horario_puede_editar(v_area) then raise exception 'Solo un admin o un líder de horarios puede editar el horario'; end if;
  update public.horario_semanas set estado = 'borrador' where id = p_semana;
end;
$$;
revoke execute on function public.horario_volver_borrador(uuid) from public, anon;
grant execute on function public.horario_volver_borrador(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar las 10 tablas de horarios con RLS activo (true)
select c.relname as tabla, c.relrowsecurity as rls_activo
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname like 'horario%' and c.relkind = 'r'
order by 1;
