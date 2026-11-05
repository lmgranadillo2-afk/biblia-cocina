-- Seguimiento comercial de eventos (vista "Seguimiento" en Costeo → Eventos). Decisiones de Miguel (5 nov 2026):
-- venue = restaurante del evento; factura y bloqueo en reservas sí/no; contabilidad aprobado / no aprobado;
-- medio de llegada: referido, WhatsApp, corporativo, líder comercial; tipo de evento texto libre;
-- reporte: enviado + fecha; anticipo: valor en pesos + texto; lo ven y editan solo el punto Eventos y el super admin.
-- Va en tabla aparte porque los restaurantes también leen costeo_eventos. No borra datos; se puede correr más de una vez.

create table if not exists public.eventos_seguimiento (
  evento_id uuid primary key references public.costeo_eventos(id) on delete cascade,
  contacto text,
  tipo_evento text,
  medio_llegada text check (medio_llegada is null or medio_llegada in ('referido', 'whatsapp', 'corporativo', 'lider_comercial')),
  exclusividad boolean not null default false,
  anticipo_valor numeric,
  anticipo_nota text,
  anticipo_fecha date,
  contabilidad_aprobado boolean not null default false,
  contabilidad_por text,
  contabilidad_at timestamptz,
  reporte_enviado boolean not null default false,
  reporte_fecha date,
  bloqueo_reservas boolean not null default false,
  factura boolean not null default false,
  actualizado_por text,
  updated_at timestamptz not null default now()
);

alter table public.eventos_seguimiento enable row level security;
drop policy if exists eventos_seguimiento_todo on public.eventos_seguimiento;
-- has_location_access ya deja pasar al super admin.
create policy eventos_seguimiento_todo on public.eventos_seguimiento for all to authenticated
  using (public.has_location_access(public.eventos_location_id()))
  with check (public.has_location_access(public.eventos_location_id()));

-- Quién y cuándo: lo pone la base.
create or replace function public.eventos_seguimiento_antes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := public.nombre_usuario_actual();
  new.updated_at := now();
  if tg_op = 'INSERT' or new.contabilidad_aprobado is distinct from old.contabilidad_aprobado then
    if new.contabilidad_aprobado then
      new.contabilidad_por := public.nombre_usuario_actual(); new.contabilidad_at := now();
    else
      new.contabilidad_por := null; new.contabilidad_at := null;
    end if;
  else
    new.contabilidad_por := old.contabilidad_por; new.contabilidad_at := old.contabilidad_at;
  end if;
  return new;
end;
$$;
drop trigger if exists eventos_seguimiento_antes on public.eventos_seguimiento;
create trigger eventos_seguimiento_antes before insert or update on public.eventos_seguimiento
  for each row execute function public.eventos_seguimiento_antes();

notify pgrst, 'reload schema';

-- Debe mostrar la tabla con 0 filas
select count(*) as filas from public.eventos_seguimiento;
