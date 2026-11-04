-- Marcación con ubicación (decisión de Miguel: cara + ubicación; lejos o sin ubicación queda DUDOSA, no se bloquea).
-- Cada punto tiene coordenadas y radio; mientras no tenga coordenadas no se revisa nada y todo sigue como hoy.
-- De la marcación solo se guarda el resultado y la distancia en metros: las coordenadas del equipo se borran al insertar.
-- La cuenta la hace la base, no el equipo. No borra datos; se puede correr más de una vez.

alter table public.locations add column if not exists geo_lat numeric(9,6);
alter table public.locations add column if not exists geo_lng numeric(9,6);
alter table public.locations add column if not exists geo_radio_m integer not null default 150;

alter table public.horario_marcaciones add column if not exists geo_lat numeric(9,6);
alter table public.horario_marcaciones add column if not exists geo_lng numeric(9,6);
alter table public.horario_marcaciones add column if not exists geo_precision_m numeric;
alter table public.horario_marcaciones add column if not exists geo_metros integer;
alter table public.horario_marcaciones add column if not exists geo_estado text;
alter table public.horario_marcaciones drop constraint if exists horario_marcaciones_geo_estado;
alter table public.horario_marcaciones add constraint horario_marcaciones_geo_estado
  check (geo_estado is null or geo_estado in ('dentro', 'fuera', 'sin_ubicacion'));

create or replace function public.horario_marcacion_geo()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_lat numeric; v_lng numeric; v_radio integer; v_d double precision;
begin
  new.geo_metros := null; new.geo_estado := null;
  if not coalesce(new.manual, false) then
    select l.geo_lat, l.geo_lng, l.geo_radio_m into v_lat, v_lng, v_radio
    from public.areas a join public.locations l on l.id = a.location_id where a.id = new.area_id;
    if v_lat is not null and v_lng is not null then
      if new.geo_lat is null or new.geo_lng is null then
        new.geo_estado := 'sin_ubicacion';
      else
        v_d := 2 * 6371000 * asin(least(1, sqrt(
          power(sin(radians(new.geo_lat - v_lat) / 2), 2)
          + cos(radians(v_lat)) * cos(radians(new.geo_lat)) * power(sin(radians(new.geo_lng - v_lng) / 2), 2))));
        new.geo_metros := round(v_d);
        -- La imprecisión del GPS da margen, hasta 100 m como máximo.
        new.geo_estado := case when v_d <= v_radio + least(coalesce(new.geo_precision_m, 0), 100) then 'dentro' else 'fuera' end;
      end if;
      if new.geo_estado <> 'dentro' then new.dudosa := true; end if;
    end if;
  end if;
  new.geo_lat := null; new.geo_lng := null; new.geo_precision_m := null;
  return new;
end;
$$;
drop trigger if exists horario_marcacion_geo on public.horario_marcaciones;
create trigger horario_marcacion_geo before insert on public.horario_marcaciones
  for each row execute function public.horario_marcacion_geo();

notify pgrst, 'reload schema';

-- Debe mostrar el disparador y los puntos todavía sin coordenadas
select tgname from pg_trigger where tgname = 'horario_marcacion_geo';
select name, geo_lat, geo_lng, geo_radio_m from public.locations order by name;
