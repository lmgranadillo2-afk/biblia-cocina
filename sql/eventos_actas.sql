-- Acta de entrega de eventos (decisiones de Miguel, 26 nov 2026), con el formato del acta de Grupo Junín:
-- 1. Información general (fecha y hora, sede, invitados, abono), 2. Menú (sale de la cotización del evento, con precios),
-- 3. Cronograma (hora / momento), 4. Observaciones, 5. Facturación electrónica, fecha de entrega y líder comercial.
-- Solo para eventos CONFIRMADOS. La crean y editan el super admin y el usuario de Eventos (seguimiento_puede_editar());
-- la ven (solo lectura, con descarga en PDF) todos los del restaurante donde se hace el evento.
-- El menú NO se copia: se toma siempre del evento. No borra datos. Se puede correr más de una vez.

create table if not exists public.eventos_actas (
  evento_id uuid primary key references public.costeo_eventos(id) on delete cascade,
  titulo text,
  fecha_hora text,
  sede text,
  invitados text,
  abono text,
  -- [{hora, momento}]
  cronograma jsonb not null default '[]'::jsonb,
  observaciones text,
  factura boolean,
  fecha_entrega date,
  lider_comercial text,
  creado_por text,
  actualizado_por text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.eventos_actas enable row level security;

-- Ver: quien edita eventos, o cualquiera con acceso al restaurante del evento si el evento está confirmado.
drop policy if exists eventos_actas_ver on public.eventos_actas;
create policy eventos_actas_ver on public.eventos_actas for select to authenticated
  using (
    public.seguimiento_puede_editar()
    or exists (select 1 from public.costeo_eventos e
               where e.id = eventos_actas.evento_id and e.estado = 'confirmado'
                 and public.has_location_access(e.restaurante_id))
  );

-- Crear: solo quien edita eventos y solo para eventos confirmados.
drop policy if exists eventos_actas_crear on public.eventos_actas;
create policy eventos_actas_crear on public.eventos_actas for insert to authenticated
  with check (
    public.seguimiento_puede_editar()
    and exists (select 1 from public.costeo_eventos e where e.id = eventos_actas.evento_id and e.estado = 'confirmado')
  );

drop policy if exists eventos_actas_editar on public.eventos_actas;
create policy eventos_actas_editar on public.eventos_actas for update to authenticated
  using (public.seguimiento_puede_editar()) with check (public.seguimiento_puede_editar());

drop policy if exists eventos_actas_borrar on public.eventos_actas;
create policy eventos_actas_borrar on public.eventos_actas for delete to authenticated
  using (public.seguimiento_puede_editar());

create or replace function public.eventos_actas_tocar()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists eventos_actas_updated on public.eventos_actas;
create trigger eventos_actas_updated before update on public.eventos_actas
  for each row execute function public.eventos_actas_tocar();

notify pgrst, 'reload schema';

-- Revisión: debe salir eventos_actas con 4 políticas.
select tablename, count(*) as politicas from pg_policies
where schemaname = 'public' and tablename = 'eventos_actas' group by tablename;
