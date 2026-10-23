-- Módulo Horarios — paso 10: marcación con reconocimiento facial (PC fijo de la cocina). Correr después de horarios_1 a 9.
-- No borra datos; se puede correr más de una vez.
--
-- Decisiones de Miguel (23 oct 2026): PC fijo con cámara en la cocina, abierto con la cuenta del líder en la pantalla de marcación;
-- reconocimiento facial SIN parpadeo; aviso al líder cuando el reconocimiento queda dudoso; tolerancia de llegada 5 min;
-- foto de evidencia por marcación (se borra a los 60 días desde la app).
-- El rostro es dato biométrico sensible (Ley 1581 de 2012): las autorizaciones firmadas las maneja la empresa por fuera de la app.
-- Se guarda una huella numérica (5 vectores de 128 números), no las fotos del registro.

-- 1) Parámetros
alter table public.horario_config add column if not exists tolerancia_min int not null default 5;

-- 2) Rostros (huellas) por persona: solo admin y líderes
create table if not exists public.horario_rostros (
  personal_id uuid primary key references public.horario_personal(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete cascade,
  descriptores jsonb not null,             -- [[128 números], ...]
  autorizacion_fecha date,                 -- sin uso: las autorizaciones se manejan por fuera de la app
  registrado_por text,
  updated_at timestamptz not null default now()
);
alter table public.horario_rostros alter column autorizacion_fecha drop not null;
alter table public.horario_rostros enable row level security;
drop policy if exists horario_rostros_ver on public.horario_rostros;
drop policy if exists horario_rostros_crear on public.horario_rostros;
drop policy if exists horario_rostros_editar on public.horario_rostros;
drop policy if exists horario_rostros_borrar on public.horario_rostros;
create policy horario_rostros_ver on public.horario_rostros for select to authenticated using (public.horario_puede_editar(area_id));
create policy horario_rostros_crear on public.horario_rostros for insert to authenticated with check (public.horario_puede_editar(area_id));
create policy horario_rostros_editar on public.horario_rostros for update to authenticated using (public.horario_puede_editar(area_id)) with check (public.horario_puede_editar(area_id));
create policy horario_rostros_borrar on public.horario_rostros for delete to authenticated using (public.horario_puede_editar(area_id));

-- 3) Marcaciones
create table if not exists public.horario_marcaciones (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id) on delete cascade,
  personal_id uuid not null references public.horario_personal(id) on delete cascade,
  tipo text not null check (tipo in ('entrada', 'salida')),
  at timestamptz not null default now(),   -- hora del servidor (la pone el disparador)
  fecha_turno date,                        -- día del turno al que pertenece (una salida de la 1 a. m. es del día anterior)
  distancia numeric(5,3),                  -- qué tan parecido fue el rostro (menor = más parecido); null si fue manual
  dudosa boolean not null default false,   -- reconocimiento dudoso: el líder la revisa
  manual boolean not null default false,   -- la marcó el líder con su clave
  estado text not null default 'valida' check (estado in ('valida', 'rechazada')),
  revisada_por text,
  revisada_at timestamptz,
  foto_path text,
  marcado_por text,
  created_at timestamptz not null default now()
);
create index if not exists horario_marcaciones_idx on public.horario_marcaciones (area_id, fecha_turno);
create index if not exists horario_marcaciones_persona_idx on public.horario_marcaciones (personal_id, at);
alter table public.horario_marcaciones enable row level security;
drop policy if exists horario_marcaciones_ver on public.horario_marcaciones;
drop policy if exists horario_marcaciones_crear on public.horario_marcaciones;
create policy horario_marcaciones_ver on public.horario_marcaciones for select to authenticated using (public.horario_puede_editar(area_id));
create policy horario_marcaciones_crear on public.horario_marcaciones for insert to authenticated with check (public.horario_puede_editar(area_id) and estado = 'valida');
-- Revisar (aceptar / rechazar) solo con la función de abajo.

-- Hora y día del turno los pone la base, no el equipo.
create or replace function public.horario_marcacion_antes()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_ult record;
begin
  new.at := now();
  new.marcado_por := public.nombre_usuario_actual();
  if new.tipo = 'entrada' then
    new.fecha_turno := (new.at at time zone 'America/Bogota')::date;
  else
    -- La salida pertenece a la última entrada abierta de las últimas 18 horas.
    select m.* into v_ult from public.horario_marcaciones m
    where m.personal_id = new.personal_id and m.estado = 'valida' and m.at > new.at - interval '18 hours'
    order by m.at desc limit 1;
    new.fecha_turno := case when v_ult.tipo = 'entrada' then v_ult.fecha_turno else (new.at at time zone 'America/Bogota')::date end;
  end if;
  return new;
end;
$$;
drop trigger if exists horario_marcacion_antes on public.horario_marcaciones;
create trigger horario_marcacion_antes before insert on public.horario_marcaciones
  for each row execute function public.horario_marcacion_antes();

-- 4) Las marcaciones llenan el registro del día (si el turno no está cerrado): llegada a tiempo o tarde, y horas reales.
create or replace function public.horario_marcaciones_a_registro(p_personal uuid, p_fecha date)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_area uuid; v_tol int; v_entrada timestamptz; v_inicio timestamptz; v_min numeric := 0; v_abierta timestamptz;
  v_tarde int; m record; v_reg record;
begin
  select area_id into v_area from public.horario_personal where id = p_personal;
  select coalesce(tolerancia_min, 5) into v_tol from public.horario_config where area_id = v_area;
  v_tol := coalesce(v_tol, 5);
  select * into v_reg from public.horario_registro_dia where personal_id = p_personal and fecha = p_fecha;
  if found and v_reg.cerrado then return; end if;
  -- Horas: suma de pares entrada → salida
  for m in select tipo, at from public.horario_marcaciones
           where personal_id = p_personal and fecha_turno = p_fecha and estado = 'valida' order by at loop
    if m.tipo = 'entrada' then
      if v_entrada is null then v_entrada := m.at; end if;
      v_abierta := m.at;
    elsif v_abierta is not null then
      v_min := v_min + extract(epoch from (m.at - v_abierta)) / 60; v_abierta := null;
    end if;
  end loop;
  if v_entrada is null then return; end if;
  -- Hora de entrada programada: primer tramo de la casilla de ese día
  select (p_fecha + (a.tramos->0->>'desde')::time) at time zone 'America/Bogota' into v_inicio
  from public.horario_asignaciones a join public.horario_semanas s on s.id = a.semana_id
  where a.personal_id = p_personal and s.lunes + (a.dia - 1) = p_fecha and a.tipo <> 'descanso' and jsonb_array_length(a.tramos) > 0
  limit 1;
  v_tarde := case when v_inicio is not null then greatest(0, floor(extract(epoch from (v_entrada - v_inicio)) / 60))::int else 0 end;
  insert into public.horario_registro_dia (area_id, personal_id, fecha, estado, asistio, minutos_tarde, horas_reales, extra)
  values (v_area, p_personal, p_fecha, case when v_tarde > v_tol then 'tarde' else 'asistio' end, true,
          case when v_tarde > v_tol then v_tarde end,
          case when v_min > 0 then round(v_min / 60 * 2) / 2 end,   -- a la media hora más cercana
          v_inicio is null)
  on conflict (personal_id, fecha) do update set
    estado = excluded.estado, asistio = true, minutos_tarde = excluded.minutos_tarde,
    horas_reales = coalesce(excluded.horas_reales, horario_registro_dia.horas_reales)
  where not horario_registro_dia.cerrado;
end;
$$;
revoke execute on function public.horario_marcaciones_a_registro(uuid, date) from public, anon;

create or replace function public.horario_marcacion_despues()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.horario_marcaciones_a_registro(new.personal_id, new.fecha_turno);
  return null;
end;
$$;
drop trigger if exists horario_marcacion_despues on public.horario_marcaciones;
create trigger horario_marcacion_despues after insert or update on public.horario_marcaciones
  for each row execute function public.horario_marcacion_despues();

-- 5) Revisar una marcación dudosa (admin o líder): aceptarla o rechazarla (rechazada no cuenta).
create or replace function public.horario_revisar_marcacion(p_id uuid, p_valida boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_area uuid;
begin
  select area_id into v_area from public.horario_marcaciones where id = p_id;
  if v_area is null then raise exception 'No encontré la marcación'; end if;
  if not public.horario_puede_editar(v_area) then raise exception 'Solo un admin o un líder puede revisar marcaciones'; end if;
  update public.horario_marcaciones
  set estado = case when p_valida then 'valida' else 'rechazada' end, dudosa = false,
      revisada_por = public.nombre_usuario_actual(), revisada_at = now()
  where id = p_id;
end;
$$;
revoke execute on function public.horario_revisar_marcacion(uuid, boolean) from public, anon;
grant execute on function public.horario_revisar_marcacion(uuid, boolean) to authenticated, service_role;

-- 6) Fotos de evidencia: bucket privado, solo admin y líderes. Ruta <área>/<fecha>/<archivo>.jpg
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('horario-marcaciones', 'horario-marcaciones', false, 1048576, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "horario marcaciones: ver" on storage.objects;
create policy "horario marcaciones: ver" on storage.objects
  for select to authenticated using (bucket_id = 'horario-marcaciones' and public.horario_puede_ver_soporte(name));
drop policy if exists "horario marcaciones: subir" on storage.objects;
create policy "horario marcaciones: subir" on storage.objects
  for insert to authenticated with check (bucket_id = 'horario-marcaciones' and public.horario_puede_ver_soporte(name));
drop policy if exists "horario marcaciones: borrar" on storage.objects;
create policy "horario marcaciones: borrar" on storage.objects
  for delete to authenticated using (bucket_id = 'horario-marcaciones' and public.horario_puede_ver_soporte(name));

-- 7) Tiempo real para "En turno ahora"
do $$ begin
  alter publication supabase_realtime add table public.horario_marcaciones;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';

-- Debe mostrar las 2 tablas con RLS activo (true) y el bucket privado
select c.relname as que, c.relrowsecurity::text as valor
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('horario_rostros', 'horario_marcaciones')
union all
select 'bucket ' || id, public::text from storage.buckets where id = 'horario-marcaciones';
