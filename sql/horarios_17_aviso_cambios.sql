-- Módulo Horarios — paso 17: aviso a cada persona cuando le cambian el turno. Correr después de horarios_1 a 16.
-- No borra datos; se puede correr más de una vez.
-- Al publicar se guarda una "foto" de la semana (persona|día → turno). Si se vuelve a publicar, la función devuelve la
-- foto anterior y la app compara: a quien le cambió algo (y tiene usuario en la app) le llega un mensaje directo en el
-- chat, con notificación al celular si las tiene activadas.

alter table public.horario_semanas add column if not exists publicado_foto jsonb;

drop function if exists public.horario_publicar(uuid);
create function public.horario_publicar(p_semana uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_area uuid; v_antes jsonb; v_foto jsonb;
begin
  select area_id, publicado_foto into v_area, v_antes from public.horario_semanas where id = p_semana;
  if v_area is null then raise exception 'No encontré la semana'; end if;
  if not public.horario_puede_editar(v_area) then raise exception 'Solo un admin o un líder de horarios puede publicar'; end if;
  select coalesce(jsonb_object_agg(a.personal_id::text || '|' || a.dia,
           case when a.tipo = 'descanso' then 'Descanso' else coalesce(a.codigo, '') end), '{}'::jsonb)
  into v_foto from public.horario_asignaciones a where a.semana_id = p_semana;
  update public.horario_semanas
  set estado = 'publicada', publicada_por = public.nombre_usuario_actual(), publicada_at = now(), publicado_foto = v_foto
  where id = p_semana;
  return v_antes;
end;
$$;
revoke execute on function public.horario_publicar(uuid) from public, anon;
grant execute on function public.horario_publicar(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar "jsonb"
select pg_get_function_result('public.horario_publicar(uuid)'::regprocedure) as devuelve;
