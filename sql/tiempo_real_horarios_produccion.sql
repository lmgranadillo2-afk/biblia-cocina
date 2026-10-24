-- Tiempo real en Horarios y Producción: los cambios se ven al instante en todos los equipos. No borra datos; se puede correr más de una vez.
-- Supabase respeta los permisos (RLS): cada quien solo recibe los cambios que ya podía ver.
do $$
declare t text;
begin
  foreach t in array array['horario_semanas', 'horario_asignaciones', 'horario_tarea_asignaciones', 'horario_novedades',
                           'horario_registro_dia', 'horario_dias_cerrados', 'horario_turnos_habilitados', 'productions'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Debe mostrar las 8 tablas (más las que ya estaban: chat, marcaciones, pedidos, bajas)
select tablename from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' order by 1;
