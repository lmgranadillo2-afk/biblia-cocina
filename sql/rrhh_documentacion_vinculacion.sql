-- Módulo de Recursos Humanos: documentación de vinculación de nuevos ingresos.
-- El candidato NO tiene usuario de la app: sube todo por un enlace público con
-- token (sin login), atendido por la Edge Function "rrhh-upload" (service role).
-- Por eso estas tablas y el bucket NO tienen política para "anon" — todo acceso
-- sin sesión pasa exclusivamente por la función, nunca directo a la base.

create table if not exists public.rrhh_solicitudes (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  nombre_candidato text not null,
  cedula_candidato text,
  location_id uuid references public.locations(id),
  estado_civil text check (estado_civil in ('soltero','casado','union_libre')),
  tiene_hijos boolean not null default false,
  conyuge_trabaja boolean not null default false,
  tiene_padres_dependientes boolean not null default false,
  estado text not null default 'pendiente' check (estado in ('pendiente','completo','revisado')),
  creado_por uuid references auth.users(id),
  created_at timestamptz not null default now(),
  expira_at timestamptz not null default (now() + interval '15 days'),
  completado_at timestamptz,
  revisado_por text,
  revisado_at timestamptz
);

create table if not exists public.rrhh_documentos (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.rrhh_solicitudes(id) on delete cascade,
  tipo text not null,
  storage_path text not null,
  nombre_archivo text,
  subido_at timestamptz not null default now()
);

create table if not exists public.rrhh_referencias (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.rrhh_solicitudes(id) on delete cascade,
  nombre text not null,
  telefono text not null,
  relacion text,
  created_at timestamptz not null default now()
);

alter table public.rrhh_solicitudes enable row level security;
alter table public.rrhh_documentos enable row level security;
alter table public.rrhh_referencias enable row level security;

create policy rrhh_solicitudes_rw on public.rrhh_solicitudes
  for all using (is_admin() or es_rrhh()) with check (is_admin() or es_rrhh());

create policy rrhh_documentos_rw on public.rrhh_documentos
  for all using (is_admin() or es_rrhh()) with check (is_admin() or es_rrhh());

create policy rrhh_referencias_rw on public.rrhh_referencias
  for all using (is_admin() or es_rrhh()) with check (is_admin() or es_rrhh());

-- Bucket privado para los documentos subidos (igual patrón que horario-soportes/chat-fotos)
insert into storage.buckets (id, name, public)
values ('rrhh-documentos', 'rrhh-documentos', false)
on conflict (id) do nothing;

create policy rrhh_documentos_storage on storage.objects
  for all using (bucket_id = 'rrhh-documentos' and (is_admin() or es_rrhh()))
  with check (bucket_id = 'rrhh-documentos' and (is_admin() or es_rrhh()));

notify pgrst, 'reload schema';
