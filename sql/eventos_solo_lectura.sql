-- Eventos: solo el super admin y el usuario de Eventos (profiles.edita_seguimiento_eventos,
-- eventosgrupojunin@) crean, editan, cambian el estado o borran eventos. Todos los demás
-- (restaurantes, punto Admin, otros usuarios del punto Eventos) solo los VEN, con la misma
-- regla de lectura de antes. Decisión de Miguel, 20 nov 2026.
-- No borra datos. Se puede correr más de una vez.

-- Misma función del seguimiento (sql/eventos_seguimiento_permisos.sql); se repite para que el script ande solo.
alter table public.profiles add column if not exists edita_seguimiento_eventos boolean not null default false;

create or replace function public.seguimiento_puede_editar()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin()
      or coalesce((select edita_seguimiento_eventos from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.seguimiento_puede_editar() from public, anon;
grant execute on function public.seguimiento_puede_editar() to authenticated, service_role;

drop policy if exists costeo_eventos_insert on public.costeo_eventos;
drop policy if exists costeo_eventos_update on public.costeo_eventos;
drop policy if exists costeo_eventos_delete on public.costeo_eventos;

create policy costeo_eventos_insert on public.costeo_eventos for insert to authenticated
  with check (public.seguimiento_puede_editar());
create policy costeo_eventos_update on public.costeo_eventos for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());
create policy costeo_eventos_delete on public.costeo_eventos for delete to authenticated
  using (public.seguimiento_puede_editar());

notify pgrst, 'reload schema';

-- 1) Políticas de costeo_eventos: insert/update/delete deben decir seguimiento_puede_editar().
--    Si sale alguna OTRA política de insert/update/delete además de esas tres, avísale a Claude
--    (las políticas se suman y esa seguiría dejando editar).
select policyname, cmd, qual, with_check
from pg_policies where schemaname = 'public' and tablename = 'costeo_eventos' order by cmd, policyname;

-- 2) Quiénes pueden editar eventos además del super admin (debe salir solo eventosgrupojunin@).
select u.email from public.profiles p join auth.users u on u.id = p.id where p.edita_seguimiento_eventos;
