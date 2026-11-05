-- Seguimiento de eventos: lo ven todos los que tienen acceso a los puntos Eventos o Admin (solo lectura);
-- solo editan los super admin y quien tenga profiles.edita_seguimiento_eventos (eventosgrupojunin@, decisión de Miguel 5 nov).
-- No borra datos; se puede correr más de una vez.
alter table public.profiles add column if not exists edita_seguimiento_eventos boolean not null default false;
update public.profiles p set edita_seguimiento_eventos = true
from auth.users u where u.id = p.id and lower(u.email) = 'eventosgrupojunin@cantinadossantos.com';

create or replace function public.seguimiento_puede_editar()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin()
      or coalesce((select edita_seguimiento_eventos from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.seguimiento_puede_editar() from public, anon;
grant execute on function public.seguimiento_puede_editar() to authenticated, service_role;

drop policy if exists eventos_seguimiento_todo on public.eventos_seguimiento;
drop policy if exists eventos_seguimiento_ver on public.eventos_seguimiento;
drop policy if exists eventos_seguimiento_crear on public.eventos_seguimiento;
drop policy if exists eventos_seguimiento_editar on public.eventos_seguimiento;
drop policy if exists eventos_seguimiento_borrar on public.eventos_seguimiento;
create policy eventos_seguimiento_ver on public.eventos_seguimiento for select to authenticated
  using (public.is_eventos_user());
create policy eventos_seguimiento_crear on public.eventos_seguimiento for insert to authenticated
  with check (public.seguimiento_puede_editar());
create policy eventos_seguimiento_editar on public.eventos_seguimiento for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());
create policy eventos_seguimiento_borrar on public.eventos_seguimiento for delete to authenticated
  using (public.seguimiento_puede_editar());

notify pgrst, 'reload schema';

-- Debe mostrar solo a eventosgrupojunin@cantinadossantos.com
select u.email from public.profiles p join auth.users u on u.id = p.id where p.edita_seguimiento_eventos;
