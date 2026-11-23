-- Registro de tiempo de uso de la app (decisiones de Miguel, 23 nov 2026):
--   * Minutos reales de uso por persona, día, punto, área y pestaña, más cuántas veces abre la app.
--   * Solo cuenta con la app visible y con un toque, clic o tecla en los últimos 5 minutos; la pantalla de
--     marcación (kiosco) no cuenta.
--   * Lo ven solo los super admin y Gerencia (perfil Informes), en Informes → Uso de la app.
--   * Se guarda 12 meses.
-- Nadie escribe en la tabla directamente: los minutos solo entran por uso_sumar (máximo 10 por envío).
-- No borra datos. Se puede correr más de una vez.

create table if not exists public.uso_app (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  fecha date not null,
  location_id uuid references public.locations(id) on delete set null,
  area_id uuid references public.areas(id) on delete set null,
  modulo text not null,
  minutos int not null default 0,
  aperturas int not null default 0,
  updated_at timestamptz not null default now()
);
create unique index if not exists uso_app_unico on public.uso_app
  (user_id, fecha, modulo, coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(area_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists uso_app_fecha_idx on public.uso_app (fecha);
alter table public.uso_app enable row level security;

create or replace function public.uso_puede_ver()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin()
      or coalesce((select es_informes from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.uso_puede_ver() from public, anon;
grant execute on function public.uso_puede_ver() to authenticated, service_role;

drop policy if exists uso_app_ver on public.uso_app;
create policy uso_app_ver on public.uso_app for select to authenticated using (public.uso_puede_ver());
-- Sin políticas de insert/update/delete: solo la función uso_sumar escribe.

-- Suma minutos y aperturas a la fila del día de quien llama.
create or replace function public.uso_sumar(p_fecha date, p_location uuid, p_area uuid, p_modulo text, p_minutos int, p_aperturas int)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_hoy date := (now() at time zone 'America/Bogota')::date;
  v_min int := least(greatest(coalesce(p_minutos, 0), 0), 10);
  v_ap int := least(greatest(coalesce(p_aperturas, 0), 0), 5);
  v_mod text := lower(coalesce(p_modulo, ''));
begin
  if v_uid is null then return; end if;
  if v_min = 0 and v_ap = 0 then return; end if;
  if p_fecha is null or p_fecha < v_hoy - 1 or p_fecha > v_hoy then return; end if;   -- solo hoy o ayer
  if v_mod !~ '^[a-z_]{1,30}$' then v_mod := 'otro'; end if;
  update public.uso_app u
     set minutos = u.minutos + v_min, aperturas = u.aperturas + v_ap, updated_at = now()
   where u.user_id = v_uid and u.fecha = p_fecha and u.modulo = v_mod
     and u.location_id is not distinct from p_location and u.area_id is not distinct from p_area;
  if not found then
    insert into public.uso_app (user_id, fecha, location_id, area_id, modulo, minutos, aperturas)
    values (v_uid, p_fecha, p_location, p_area, v_mod, v_min, v_ap)
    on conflict do nothing;
    if not found then   -- otra ventana de la misma persona la creó en ese instante
      update public.uso_app u
         set minutos = u.minutos + v_min, aperturas = u.aperturas + v_ap, updated_at = now()
       where u.user_id = v_uid and u.fecha = p_fecha and u.modulo = v_mod
         and u.location_id is not distinct from p_location and u.area_id is not distinct from p_area;
    end if;
  end if;
end $$;
revoke execute on function public.uso_sumar(date, uuid, uuid, text, int, int) from public, anon;
grant execute on function public.uso_sumar(date, uuid, uuid, text, int, int) to authenticated, service_role;

-- Datos para el informe (con nombres de persona, punto y área). Solo super admin y Gerencia.
create or replace function public.uso_app_informe(p_desde date, p_hasta date, p_location uuid default null, p_area uuid default null)
returns table (r_fecha date, r_user_id uuid, r_persona text, r_location_id uuid, r_punto text, r_area_id uuid, r_area text, r_modulo text, r_minutos int, r_aperturas int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.uso_puede_ver() then raise exception 'Solo super admin y Gerencia ven el uso de la app'; end if;
  return query
    select u.fecha, u.user_id,
           coalesce(nullif(trim(p.name), ''), au.email)::text,
           u.location_id, l.name::text, u.area_id, a.name::text, u.modulo, u.minutos, u.aperturas
    from public.uso_app u
    left join public.profiles p on p.id = u.user_id
    left join auth.users au on au.id = u.user_id
    left join public.locations l on l.id = u.location_id
    left join public.areas a on a.id = u.area_id
    where u.fecha between p_desde and p_hasta
      and (p_location is null or u.location_id = p_location)
      and (p_area is null or u.area_id = p_area)
    order by u.fecha;
end $$;
revoke execute on function public.uso_app_informe(date, date, uuid, uuid) from public, anon;
grant execute on function public.uso_app_informe(date, date, uuid, uuid) to authenticated, service_role;

-- Limpieza: se guarda 12 meses. Tarea mensual (día 1, 3 a. m. Colombia = 08:00 UTC).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'uso-app-limpieza';
    perform cron.schedule('uso-app-limpieza', '0 8 1 * *', 'delete from public.uso_app where fecha < (now() at time zone ''America/Bogota'')::date - interval ''12 months''');
  end if;
end $$;

notify pgrst, 'reload schema';

-- Revisión: deben salir la tabla uso_app y la tarea uso-app-limpieza.
select 'tabla' as que, tablename::text as nombre from pg_tables where schemaname = 'public' and tablename = 'uso_app'
union all
select 'tarea', jobname::text from cron.job where jobname = 'uso-app-limpieza';
