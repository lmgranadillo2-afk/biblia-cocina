-- Calculadora de precios también para admins normales.
-- Cada admin ve y edita solo los platos que guardó; el super admin ve y edita todos. No borra datos; se puede correr más de una vez.
drop policy if exists calculadora_platos_admin on public.calculadora_platos;
create policy calculadora_platos_admin on public.calculadora_platos for all to authenticated
  using (public.is_admin() and created_by = auth.uid())
  with check (public.is_admin() and created_by = auth.uid());

-- Debe mostrar las dos políticas
select policyname from pg_policies where schemaname = 'public' and tablename = 'calculadora_platos';
