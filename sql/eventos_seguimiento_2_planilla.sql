-- Seguimiento de eventos, paso 2 (decisiones de Miguel, 5 nov 2026, al cargar su planilla):
-- medio de llegada = WhatsApp corporativo / Referido / Líder comercial + "referido por" (texto);
-- columna nueva "Tabla de abonos" (sí/no); valor cotizado manual para eventos sin cotización en la app;
-- detalle del estado como texto (ej. "pendiente anticipo"). No borra datos; se puede correr más de una vez.
-- La carga de la planilla en sí (con teléfonos de clientes) se corrió aparte y no se guarda en el repo.
alter table public.eventos_seguimiento drop constraint if exists eventos_seguimiento_medio_llegada_check;
update public.eventos_seguimiento set medio_llegada = 'whatsapp_corporativo' where medio_llegada in ('whatsapp', 'corporativo');
alter table public.eventos_seguimiento add constraint eventos_seguimiento_medio_llegada_check
  check (medio_llegada is null or medio_llegada in ('whatsapp_corporativo', 'referido', 'lider_comercial'));
alter table public.eventos_seguimiento add column if not exists referido_por text;
alter table public.eventos_seguimiento add column if not exists tabla_abonos boolean not null default false;
alter table public.eventos_seguimiento add column if not exists valor_manual numeric;
alter table public.eventos_seguimiento add column if not exists estado_detalle text;

notify pgrst, 'reload schema';

-- Debe mostrar las 4 columnas nuevas
select column_name from information_schema.columns where table_schema = 'public' and table_name = 'eventos_seguimiento'
  and column_name in ('referido_por', 'tabla_abonos', 'valor_manual', 'estado_detalle');
