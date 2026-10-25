-- Módulo Horarios — paso 18: si la persona ya marcó ese día, su turno de ese día no se puede cambiar. Correr después de horarios_1 a 17.
-- No borra datos; se puede correr más de una vez.
-- Así un líder no puede "tapar" una llegada tarde moviendo el horario después de la marcación; las correcciones van
-- en Registro del día. Un admin (o super admin) sí puede cambiarlo.

create or replace function public.horario_asig_candado_marcacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_pid uuid; v_fecha date;
begin
  if public.is_admin() or public.is_super_admin() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  -- La casilla de antes (al cambiar o borrar) y la de después (al crear o cambiar)
  if tg_op in ('UPDATE', 'DELETE') then
    select old.personal_id, s.lunes + (old.dia - 1) into v_pid, v_fecha from public.horario_semanas s where s.id = old.semana_id;
    if exists (select 1 from public.horario_marcaciones m where m.personal_id = v_pid and m.fecha_turno = v_fecha and m.estado = 'valida') then
      raise exception 'Esa persona ya marcó el %: su turno no se puede cambiar. Corrígelo en Registro del día.', to_char(v_fecha, 'DD/MM');
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    select new.personal_id, s.lunes + (new.dia - 1) into v_pid, v_fecha from public.horario_semanas s where s.id = new.semana_id;
    if exists (select 1 from public.horario_marcaciones m where m.personal_id = v_pid and m.fecha_turno = v_fecha and m.estado = 'valida') then
      raise exception 'Esa persona ya marcó el %: su turno no se puede cambiar. Corrígelo en Registro del día.', to_char(v_fecha, 'DD/MM');
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists horario_asig_candado_marcacion on public.horario_asignaciones;
create trigger horario_asig_candado_marcacion before insert or update or delete on public.horario_asignaciones
  for each row execute function public.horario_asig_candado_marcacion();

-- Debe mostrar el disparador
select tgname from pg_trigger where tgname = 'horario_asig_candado_marcacion';
