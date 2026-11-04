-- Marcación solo dentro del rango del punto (decisión de Miguel; reemplaza "lejos o sin ubicación queda dudosa").
-- Si el punto tiene coordenadas: fuera del radio o sin ubicación NO se guarda la marcación. La manual del líder no se revisa.
-- Puntos sin coordenadas: sigue como hoy. No borra datos; se puede correr más de una vez.
-- Correr DESPUÉS de que Vercel despliegue la app que muestra el aviso.

create or replace function public.horario_geo_evaluar(p_area uuid, p_lat numeric, p_lng numeric, p_precision numeric)
returns table (estado text, metros integer)
language plpgsql stable security definer set search_path = public as $$
declare v_lat numeric; v_lng numeric; v_radio integer; v_d double precision;
begin
  select l.geo_lat, l.geo_lng, l.geo_radio_m into v_lat, v_lng, v_radio
  from public.areas a join public.locations l on l.id = a.location_id where a.id = p_area;
  if v_lat is null or v_lng is null then estado := null; metros := null; return next; return; end if;
  if p_lat is null or p_lng is null then estado := 'sin_ubicacion'; metros := null; return next; return; end if;
  v_d := 2 * 6371000 * asin(least(1, sqrt(
    power(sin(radians(p_lat - v_lat) / 2), 2)
    + cos(radians(v_lat)) * cos(radians(p_lat)) * power(sin(radians(p_lng - v_lng) / 2), 2))));
  metros := round(v_d);
  -- La imprecisión del GPS da margen, hasta 100 m como máximo.
  estado := case when v_d <= v_radio + least(coalesce(p_precision, 0), 100) then 'dentro' else 'fuera' end;
  return next;
end;
$$;
revoke execute on function public.horario_geo_evaluar(uuid, numeric, numeric, numeric) from public, anon;
grant execute on function public.horario_geo_evaluar(uuid, numeric, numeric, numeric) to authenticated, service_role;

create or replace function public.horario_marcacion_geo()
returns trigger language plpgsql security definer set search_path = public as $$
declare v record;
begin
  new.geo_metros := null; new.geo_estado := null;
  if not coalesce(new.manual, false) then
    select * into v from public.horario_geo_evaluar(new.area_id, new.geo_lat, new.geo_lng, new.geo_precision_m);
    if v.estado = 'fuera' then raise exception 'Estás fuera del rango del restaurante (a % m). No se guardó la marcación.', v.metros; end if;
    if v.estado = 'sin_ubicacion' then raise exception 'No hay ubicación del equipo. No se guardó la marcación.'; end if;
    new.geo_metros := v.metros; new.geo_estado := v.estado;
  end if;
  new.geo_lat := null; new.geo_lng := null; new.geo_precision_m := null;
  return new;
end;
$$;

notify pgrst, 'reload schema';

-- Debe mostrar la función nueva
select proname from pg_proc where proname = 'horario_geo_evaluar';
