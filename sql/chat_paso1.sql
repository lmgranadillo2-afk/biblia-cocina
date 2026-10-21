-- Chat interno · Paso 1: grupo de cada punto + mensajes directos, con fotos.
-- Quién ve qué:
--   · Grupo del punto: todos los que tienen acceso a ese punto (has_location_access).
--   · Directo: solo las dos personas. Se puede abrir con alguien con quien compartes al menos un punto
--     (el super admin, con cualquiera).
--   · Fotos: bucket privado "chat-fotos", carpeta = id de la conversación; solo las ven los de esa conversación.
-- Los mensajes no se editan ni se borran desde la app.
-- No borra nada. Se puede correr más de una vez.

-- 1) Conversaciones
create table if not exists public.chat_conversaciones (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('punto', 'directo')),
  location_id uuid references public.locations(id) on delete cascade,
  usuario_a uuid references auth.users(id) on delete cascade,
  usuario_b uuid references auth.users(id) on delete cascade,
  ultimo_at timestamptz not null default now(),
  ultimo_texto text,
  ultimo_autor text,
  created_at timestamptz not null default now(),
  constraint chat_conv_forma check (
    (tipo = 'punto' and location_id is not null and usuario_a is null and usuario_b is null) or
    (tipo = 'directo' and location_id is null and usuario_a is not null and usuario_b is not null and usuario_a < usuario_b))
);
create unique index if not exists chat_conv_punto_uq on public.chat_conversaciones(location_id) where tipo = 'punto';
create unique index if not exists chat_conv_directo_uq on public.chat_conversaciones(usuario_a, usuario_b) where tipo = 'directo';

-- 2) Mensajes
create table if not exists public.chat_mensajes (
  id uuid primary key default gen_random_uuid(),
  conversacion_id uuid not null references public.chat_conversaciones(id) on delete cascade,
  autor_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  autor_nombre text,
  autor_area text,
  texto text check (texto is null or char_length(texto) <= 4000),
  foto_path text,
  created_at timestamptz not null default now(),
  constraint chat_msg_contenido check (coalesce(nullif(trim(texto), ''), foto_path) is not null)
);
create index if not exists chat_mensajes_conv_idx on public.chat_mensajes(conversacion_id, created_at desc);

-- 3) Hasta dónde leyó cada persona cada conversación (para los no leídos)
create table if not exists public.chat_lecturas (
  conversacion_id uuid not null references public.chat_conversaciones(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  leido_at timestamptz not null default now(),
  primary key (conversacion_id, user_id)
);

-- 4) ¿El usuario actual puede ver esta conversación?
create or replace function public.chat_puede_ver(p_conv uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_conversaciones c
    where c.id = p_conv
      and ((c.tipo = 'punto' and public.has_location_access(c.location_id))
        or (c.tipo = 'directo' and auth.uid() in (c.usuario_a, c.usuario_b))));
$$;

-- 5) Permisos (RLS)
alter table public.chat_conversaciones enable row level security;
alter table public.chat_mensajes enable row level security;
alter table public.chat_lecturas enable row level security;

drop policy if exists "chat conv: ver" on public.chat_conversaciones;
create policy "chat conv: ver" on public.chat_conversaciones
  for select to authenticated using (public.chat_puede_ver(id));
-- Las conversaciones solo se crean con las funciones de abajo.

drop policy if exists "chat msg: ver" on public.chat_mensajes;
create policy "chat msg: ver" on public.chat_mensajes
  for select to authenticated using (public.chat_puede_ver(conversacion_id));
drop policy if exists "chat msg: escribir" on public.chat_mensajes;
create policy "chat msg: escribir" on public.chat_mensajes
  for insert to authenticated with check (autor_id = auth.uid() and public.chat_puede_ver(conversacion_id));

drop policy if exists "chat lect: propias" on public.chat_lecturas;
create policy "chat lect: propias" on public.chat_lecturas
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.chat_puede_ver(conversacion_id));

-- 6) Al llegar un mensaje: queda como último de la conversación, y quien lo escribió lo da por leído
create or replace function public.chat_tras_mensaje()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_conversaciones
  set ultimo_at = new.created_at,
      ultimo_texto = case when coalesce(trim(new.texto), '') = '' then '📷 Foto' else left(new.texto, 140) end,
      ultimo_autor = new.autor_nombre
  where id = new.conversacion_id;
  insert into public.chat_lecturas (conversacion_id, user_id, leido_at)
  values (new.conversacion_id, new.autor_id, new.created_at)
  on conflict (conversacion_id, user_id) do update set leido_at = excluded.leido_at;
  return new;
end;
$$;
drop trigger if exists chat_tras_mensaje on public.chat_mensajes;
create trigger chat_tras_mensaje after insert on public.chat_mensajes
  for each row execute function public.chat_tras_mensaje();

-- 7) Grupo del punto (se crea la primera vez que alguien lo abre)
create or replace function public.chat_grupo_punto(p_location_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.has_location_access(p_location_id) then raise exception 'No tienes acceso a este punto'; end if;
  insert into public.chat_conversaciones (tipo, location_id) values ('punto', p_location_id)
  on conflict (location_id) where tipo = 'punto' do nothing;
  select id into v_id from public.chat_conversaciones where tipo = 'punto' and location_id = p_location_id;
  return v_id;
end;
$$;

-- 8) Abrir (o crear) un directo con otra persona
create or replace function public.chat_abrir_directo(p_otro uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_a uuid; v_b uuid; v_id uuid;
begin
  if p_otro is null or p_otro = auth.uid() then raise exception 'Elige a otra persona'; end if;
  if not (public.is_super_admin() or exists (
      select 1 from public.user_locations u1 join public.user_locations u2 on u2.location_id = u1.location_id
      where u1.user_id = auth.uid() and u2.user_id = p_otro)) then
    raise exception 'Solo puedes escribirle a personas de tus puntos';
  end if;
  v_a := least(auth.uid(), p_otro); v_b := greatest(auth.uid(), p_otro);
  insert into public.chat_conversaciones (tipo, usuario_a, usuario_b) values ('directo', v_a, v_b)
  on conflict (usuario_a, usuario_b) where tipo = 'directo' do nothing;
  select id into v_id from public.chat_conversaciones where tipo = 'directo' and usuario_a = v_a and usuario_b = v_b;
  return v_id;
end;
$$;

-- 9) Personas del punto (para empezar un directo): nombre y áreas en ese punto
create or replace function public.chat_personas(p_location_id uuid)
returns table (id uuid, nombre text, areas text, rol text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, coalesce(nullif(trim(p.name), ''), 'Sin nombre'),
    (select string_agg(a.name, ', ' order by a.name) from public.user_areas ua join public.areas a on a.id = ua.area_id
      where ua.user_id = p.id and a.location_id = p_location_id),
    p.role
  from public.profiles p
  where public.has_location_access(p_location_id)
    and p.id <> auth.uid()
    and exists (select 1 from public.user_locations ul where ul.user_id = p.id and ul.location_id = p_location_id)
  order by 2;
$$;

-- 10) Mis conversaciones: el grupo del punto + mis directos, con no leídos
create or replace function public.chat_mis_conversaciones(p_location_id uuid)
returns table (id uuid, tipo text, titulo text, subtitulo text, otro_id uuid, ultimo_at timestamptz,
               ultimo_texto text, ultimo_autor text, no_leidos integer)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.tipo,
    case when c.tipo = 'punto' then l.name else coalesce(nullif(trim(po.name), ''), 'Sin nombre') end,
    case when c.tipo = 'punto' then 'Todo el punto' else
      coalesce((select string_agg(distinct a.name, ', ') from public.user_areas ua join public.areas a on a.id = ua.area_id
        where ua.user_id = po.id and a.location_id = p_location_id), 'Otro punto') end,
    po.id, c.ultimo_at, c.ultimo_texto, c.ultimo_autor,
    (select count(*)::int from public.chat_mensajes m
      where m.conversacion_id = c.id and m.autor_id <> auth.uid()
        and m.created_at > coalesce((select r.leido_at from public.chat_lecturas r where r.conversacion_id = c.id and r.user_id = auth.uid()), '-infinity'::timestamptz))
  from public.chat_conversaciones c
  left join public.locations l on l.id = c.location_id
  left join public.profiles po on c.tipo = 'directo' and po.id = case when c.usuario_a = auth.uid() then c.usuario_b else c.usuario_a end
  where (c.tipo = 'punto' and c.location_id = p_location_id and public.has_location_access(p_location_id))
     or (c.tipo = 'directo' and auth.uid() in (c.usuario_a, c.usuario_b))
  order by (c.tipo = 'punto') desc, c.ultimo_at desc;
$$;

revoke execute on function public.chat_puede_ver(uuid) from public, anon;
revoke execute on function public.chat_grupo_punto(uuid) from public, anon;
revoke execute on function public.chat_abrir_directo(uuid) from public, anon;
revoke execute on function public.chat_personas(uuid) from public, anon;
revoke execute on function public.chat_mis_conversaciones(uuid) from public, anon;
grant execute on function public.chat_puede_ver(uuid) to authenticated, service_role;
grant execute on function public.chat_grupo_punto(uuid) to authenticated, service_role;
grant execute on function public.chat_abrir_directo(uuid) to authenticated, service_role;
grant execute on function public.chat_personas(uuid) to authenticated, service_role;
grant execute on function public.chat_mis_conversaciones(uuid) to authenticated, service_role;

-- 11) Tiempo real: los mensajes nuevos llegan al instante (respetando los permisos de arriba)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_mensajes') then
    alter publication supabase_realtime add table public.chat_mensajes;
  end if;
end $$;

-- 12) Fotos: bucket privado, máximo 5 MB, solo imágenes
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-fotos', 'chat-fotos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Ruta de cada foto: <id de la conversación>/<archivo>
create or replace function public.chat_puede_ver_foto(p_nombre text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_conv uuid;
begin
  begin v_conv := split_part(p_nombre, '/', 1)::uuid; exception when others then return false; end;
  return public.chat_puede_ver(v_conv);
end;
$$;
revoke execute on function public.chat_puede_ver_foto(text) from public, anon;
grant execute on function public.chat_puede_ver_foto(text) to authenticated, service_role;

drop policy if exists "chat fotos: ver" on storage.objects;
create policy "chat fotos: ver" on storage.objects
  for select to authenticated using (bucket_id = 'chat-fotos' and public.chat_puede_ver_foto(name));
drop policy if exists "chat fotos: subir" on storage.objects;
create policy "chat fotos: subir" on storage.objects
  for insert to authenticated with check (bucket_id = 'chat-fotos' and public.chat_puede_ver_foto(name));

notify pgrst, 'reload schema';

-- Debe mostrar las 3 tablas, el bucket y la tabla en tiempo real
select 'tabla' as que, tablename as nombre from pg_tables where schemaname = 'public' and tablename like 'chat_%'
union all select 'bucket', id from storage.buckets where id = 'chat-fotos'
union all select 'tiempo real', tablename from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'chat_mensajes';
