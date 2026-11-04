-- Novedad de Horarios: calamidad doméstica. Cuenta como ausencia igual que las demás (todo lo que no sea retardo).
-- No borra datos; se puede correr más de una vez.
alter table public.horario_novedades drop constraint if exists horario_novedades_tipo_check;
alter table public.horario_novedades add constraint horario_novedades_tipo_check
  check (tipo in ('incapacidad', 'vacaciones', 'permiso', 'calamidad', 'vacante', 'retardo'));

-- Debe mostrar la regla con calamidad
select pg_get_constraintdef(oid) from pg_constraint where conname = 'horario_novedades_tipo_check';
