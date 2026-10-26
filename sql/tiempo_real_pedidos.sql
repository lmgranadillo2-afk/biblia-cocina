-- Tiempo real completo en Pedidos (y Bajas): los cambios se ven al instante en todos los equipos.
-- No borra datos; se puede correr más de una vez. Supabase respeta los permisos (RLS).
do $$
declare t text;
begin
  foreach t in array array['orders', 'order_items', 'bajas'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Debe incluir orders, order_items y bajas
select tablename from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' order by 1;
