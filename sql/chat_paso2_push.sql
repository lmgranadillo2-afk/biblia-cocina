-- Chat interno · Paso 2: notificaciones al celular aunque la app esté cerrada (Web Push).
-- 1) Cada celular/computador que activa las notificaciones queda guardado (una fila por dispositivo).
-- 2) Al llegar un mensaje, la base llama a la función "chat-push" de Supabase, que manda la notificación
--    a los demás de la conversación (grupo del punto: todos los del punto; directo: la otra persona).
-- Correr DESPUÉS de crear la función chat-push y sus secretos (VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT).
-- No borra nada. Se puede correr más de una vez.

create extension if not exists pg_net;

-- 1) Dispositivos suscritos
create table if not exists public.push_suscripciones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  actualizado_at timestamptz not null default now()
);
create index if not exists push_suscripciones_user_idx on public.push_suscripciones(user_id);
alter table public.push_suscripciones enable row level security;
drop policy if exists "push: ver las mias" on public.push_suscripciones;
create policy "push: ver las mias" on public.push_suscripciones
  for select to authenticated using (user_id = auth.uid());
-- Se guardan y borran solo con las funciones de abajo (un mismo dispositivo puede cambiar de usuario).

create or replace function public.push_guardar(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  insert into public.push_suscripciones (user_id, endpoint, p256dh, auth, user_agent)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(p_user_agent, 300))
  on conflict (endpoint) do update
    set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth,
        user_agent = excluded.user_agent, actualizado_at = now();
end;
$$;

create or replace function public.push_borrar(p_endpoint text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_suscripciones where endpoint = p_endpoint and user_id = auth.uid();
$$;

revoke execute on function public.push_guardar(text, text, text, text) from public, anon;
revoke execute on function public.push_borrar(text) from public, anon;
grant execute on function public.push_guardar(text, text, text, text) to authenticated, service_role;
grant execute on function public.push_borrar(text) to authenticated, service_role;

-- 2) Token interno con el que la base se identifica ante la función (se genera solo; nadie lo copia).
create table if not exists public.chat_push_config (
  id int primary key default 1 check (id = 1),
  token text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
);
alter table public.chat_push_config enable row level security; -- sin políticas: nadie la lee desde la app
insert into public.chat_push_config (id) values (1) on conflict (id) do nothing;

-- 3) Al llegar un mensaje: avisar a la función (sin esperar respuesta; si falla, el mensaje igual queda guardado)
create or replace function public.chat_enviar_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    perform net.http_post(
      url := 'https://rwsmscggszaogalmwsrj.supabase.co/functions/v1/chat-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_ZHjOiAmgamvaTcLfluTxxA_tkhOX-Ve'),
      body := jsonb_build_object(
        'token', (select token from public.chat_push_config where id = 1),
        'mensaje_id', new.id),
      timeout_milliseconds := 10000);
  exception when others then
    null; -- nunca bloquear el envío del mensaje por un problema de notificaciones
  end;
  return new;
end;
$$;
drop trigger if exists chat_enviar_push on public.chat_mensajes;
create trigger chat_enviar_push after insert on public.chat_mensajes
  for each row execute function public.chat_enviar_push();

notify pgrst, 'reload schema';

-- Debe mostrar la tabla de suscripciones, el token creado y el disparador
select 'tabla' as que, tablename::text as nombre from pg_tables where schemaname = 'public' and tablename = 'push_suscripciones'
union all select 'token', case when exists (select 1 from public.chat_push_config) then 'creado' else 'falta' end
union all select 'disparador', tgname::text from pg_trigger where tgname = 'chat_enviar_push';
