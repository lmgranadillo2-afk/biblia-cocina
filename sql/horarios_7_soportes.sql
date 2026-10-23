-- Módulo Horarios — paso 7: soportes de novedades (foto o PDF, ej. la incapacidad médica).
-- Correr DESPUÉS de horarios_6. No borra datos; se puede correr más de una vez.
--
-- Los soportes son datos sensibles (salud): bucket privado "horario-soportes", solo los ven y suben admin y líderes
-- de horarios del área (igual que las novedades). Ruta de cada archivo: <área>/<novedad>/<archivo>.
-- Se pueden agregar aunque la quincena esté cerrada: un soporte no cambia horas (no queda como cambio después del cierre).

alter table public.horario_novedades add column if not exists soportes jsonb not null default '[]'::jsonb;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('horario-soportes', 'horario-soportes', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.horario_puede_ver_soporte(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_area uuid;
begin
  begin v_area := split_part(p_nombre, '/', 1)::uuid; exception when others then return false; end;
  return public.horario_puede_editar(v_area);
end;
$$;
revoke execute on function public.horario_puede_ver_soporte(text) from public, anon;
grant execute on function public.horario_puede_ver_soporte(text) to authenticated, service_role;

drop policy if exists "horario soportes: ver" on storage.objects;
create policy "horario soportes: ver" on storage.objects
  for select to authenticated using (bucket_id = 'horario-soportes' and public.horario_puede_ver_soporte(name));
drop policy if exists "horario soportes: subir" on storage.objects;
create policy "horario soportes: subir" on storage.objects
  for insert to authenticated with check (bucket_id = 'horario-soportes' and public.horario_puede_ver_soporte(name));
drop policy if exists "horario soportes: borrar" on storage.objects;
create policy "horario soportes: borrar" on storage.objects
  for delete to authenticated using (bucket_id = 'horario-soportes' and public.horario_puede_ver_soporte(name));

-- Guardar la lista de soportes de una novedad (admin o líder), aunque la quincena esté cerrada.
create or replace function public.horario_novedad_soportes(p_id uuid, p_soportes jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_area uuid;
begin
  select area_id into v_area from public.horario_novedades where id = p_id;
  if v_area is null then raise exception 'No encontré la novedad'; end if;
  if not public.horario_puede_editar(v_area) then raise exception 'Solo un admin o un líder de horarios puede adjuntar soportes'; end if;
  if jsonb_typeof(p_soportes) <> 'array' or jsonb_array_length(p_soportes) > 10 then raise exception 'Máximo 10 soportes por novedad'; end if;
  update public.horario_novedades set soportes = p_soportes where id = p_id;
end;
$$;
revoke execute on function public.horario_novedad_soportes(uuid, jsonb) from public, anon;
grant execute on function public.horario_novedad_soportes(uuid, jsonb) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar el bucket privado (public = false) con límite de 10 MB
select id, public, file_size_limit from storage.buckets where id = 'horario-soportes';
