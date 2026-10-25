-- Módulo Horarios — paso 16: cualquier usuario del área puede abrir la ventana de marcación. Correr después de horarios_1 a 15.
-- No borra datos; se puede correr más de una vez.
--  * Ver rostros (solo los números de la cara, no fotos) y registrar marcaciones por cara: cualquiera con acceso al área.
--  * Marcar a mano (manual) sigue siendo solo de admin y líderes de horarios.
--  * Ver todas las marcaciones, registrar o borrar rostros: siguen siendo de admin, líderes y Recursos humanos.

-- Rostros: lectura para quien tenga acceso al área (la ventana de marcación los necesita para reconocer)
drop policy if exists horario_rostros_ver on public.horario_rostros;
create policy horario_rostros_ver on public.horario_rostros for select to authenticated
  using (public.has_area_access(area_id) or public.es_rrhh());

-- Marcaciones: cualquiera del área marca por cara; la mano, solo líderes y admin
drop policy if exists horario_marcaciones_crear on public.horario_marcaciones;
create policy horario_marcaciones_crear on public.horario_marcaciones for insert to authenticated
  with check (estado = 'valida' and (public.horario_puede_editar(area_id) or (public.has_area_access(area_id) and not coalesce(manual, false))));

-- La ventana necesita las marcaciones de las últimas horas (para saber si toca entrada o salida)
drop policy if exists horario_marcaciones_ver on public.horario_marcaciones;
create policy horario_marcaciones_ver on public.horario_marcaciones for select to authenticated
  using (public.horario_puede_editar(area_id) or public.es_rrhh()
         or (public.has_area_access(area_id) and at > now() - interval '24 hours'));

-- Foto de evidencia: subir para quien tenga acceso al área (ver y borrar siguen siendo de líderes y admin)
create or replace function public.horario_puede_subir_marcacion(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_area uuid;
begin
  begin v_area := split_part(p_nombre, '/', 1)::uuid; exception when others then return false; end;
  return public.has_area_access(v_area);
end;
$$;
revoke execute on function public.horario_puede_subir_marcacion(text) from public, anon;
grant execute on function public.horario_puede_subir_marcacion(text) to authenticated, service_role;
drop policy if exists "horario marcaciones: subir" on storage.objects;
create policy "horario marcaciones: subir" on storage.objects
  for insert to authenticated with check (bucket_id = 'horario-marcaciones' and public.horario_puede_subir_marcacion(name));

notify pgrst, 'reload schema';

-- Debe mostrar las 3 políticas nuevas
select tablename, policyname from pg_policies
where policyname in ('horario_rostros_ver', 'horario_marcaciones_crear', 'horario_marcaciones_ver', 'horario marcaciones: subir') order by 1, 2;
