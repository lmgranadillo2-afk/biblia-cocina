-- Perfil Informes (decisión de Miguel, 5 nov 2026): solo lectura de todos los puntos y áreas, para descargar informes
-- desde la pestaña Informes. profiles.es_informes; gerencia@cantinadossantos.com. Este paso da lectura a lo de
-- Operación (pedidos, producciones, bajas, inventarios); los siguientes grupos agregan sus tablas.
-- Solo agrega políticas de LECTURA: este perfil no puede crear, cambiar ni borrar nada. Se puede correr más de una vez.
alter table public.profiles add column if not exists es_informes boolean not null default false;
update public.profiles p set es_informes = true
from auth.users u where u.id = p.id and lower(u.email) = 'gerencia@cantinadossantos.com';

create or replace function public.es_informes()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select es_informes from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.es_informes() from public, anon;
grant execute on function public.es_informes() to authenticated, service_role;

do $$
declare t text;
begin
  foreach t in array array['locations', 'areas', 'orders', 'order_items', 'order_seguimientos', 'productions', 'bajas', 'inventory_sessions', 'inventory_items'] loop
    execute format('drop policy if exists informes_ver on public.%I', t);
    execute format('create policy informes_ver on public.%I for select to authenticated using (public.es_informes())', t);
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Debe mostrar 9 tablas con la política informes_ver
select tablename from pg_policies where schemaname = 'public' and policyname = 'informes_ver' order by tablename;
