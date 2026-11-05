-- Perfil Informes, paso 2: lectura (solo select) de Horarios y nómina, Eventos, Mercadeo y Costos.
-- Incluye datos sensibles (salarios, novedades de salud, contactos de clientes, costos): decisión de Miguel (5 nov 2026).
-- Las huellas faciales (horario_rostros) NO se incluyen: no hacen falta para ningún informe.
-- Solo agrega políticas de LECTURA. Se puede correr más de una vez.
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
      and (c.relname like 'horario\_%' or c.relname in ('costeo_eventos', 'eventos_seguimiento', 'mercadeo_presupuestos', 'mercadeo_gastos',
        'mercadeo_categorias', 'carta_items', 'foodcost_informes'))
  loop
    execute format('drop policy if exists informes_ver on public.%I', t);
    execute format('create policy informes_ver on public.%I for select to authenticated using (public.es_informes())', t);
  end loop;
end $$;
drop policy if exists informes_ver on public.horario_rostros;

notify pgrst, 'reload schema';

-- Debe listar las tablas con la política informes_ver
select tablename from pg_policies where schemaname = 'public' and policyname = 'informes_ver' order by tablename;
