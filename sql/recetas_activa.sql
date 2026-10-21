-- Recetas: activar / desactivar por área. Una receta inactiva no sale en Producción, Calcular producción
-- ni Cronograma (no se puede registrar ni programar); en el Recetario queda en "Inactivas" para volver a activarla.
-- El historial (producciones, bajas) no se toca.
-- Todas las recetas quedan activas. No borra nada. Se puede correr más de una vez.

alter table public.recipes
  add column if not exists activa boolean not null default true,
  add column if not exists activa_por text,
  add column if not exists activa_at timestamptz;

-- Solo un admin con acceso al área de la receta puede cambiarlo (función propia, así no depende de la política de update de recipes).
create or replace function public.set_receta_activa(p_recipe_id uuid, p_activa boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_area uuid;
begin
  select area_id into v_area from public.recipes where id = p_recipe_id;
  if v_area is null then raise exception 'No encontré la receta'; end if;
  if not (public.is_admin() and public.has_area_access(v_area)) then
    raise exception 'Solo un admin del punto puede activar o desactivar recetas';
  end if;
  update public.recipes
  set activa = p_activa, activa_por = public.nombre_usuario_actual(), activa_at = now()
  where id = p_recipe_id;
end;
$$;

revoke execute on function public.set_receta_activa(uuid, boolean) from public, anon;
grant execute on function public.set_receta_activa(uuid, boolean) to authenticated, service_role;

notify pgrst, 'reload schema';

-- Debe mostrar cuántas recetas hay activas (todas, al correrlo la primera vez)
select count(*) filter (where activa) as activas, count(*) filter (where not activa) as inactivas from public.recipes;
