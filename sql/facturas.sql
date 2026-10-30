-- Módulo Facturas: la persona de oficina sube la foto de cada factura que llega, con proveedor,
-- monto, número y fecha. Se registra por ÁREA (igual que Pedidos y Bajas), no solo por punto.
-- No depende de que exista un pedido en la app, pero se puede asociar opcionalmente a uno
-- (orders.id) para dejar el rastro completo.
-- Correr una sola vez en el SQL Editor de Supabase.

-- 1) Rol "Facturas": igual patrón que Recursos humanos (profiles.es_rrhh / es_rrhh()).
--    Acceso GLOBAL a todos los puntos y áreas, se otorga por usuario desde Admin → Usuarios.
alter table public.profiles add column if not exists es_facturas boolean not null default false;

create or replace function public.es_facturas()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select es_facturas from public.profiles where id = auth.uid()), false);
$$;
revoke execute on function public.es_facturas() from public, anon;
grant execute on function public.es_facturas() to authenticated, service_role;

-- 2) Tabla de facturas (por área, con el punto denormalizado para filtrar rápido).
create table if not exists public.facturas (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.areas(id),
  location_id uuid not null references public.locations(id),
  proveedor text, -- opcional: con la foto alcanza, se puede completar después
  numero_factura text,
  monto numeric,
  fecha_factura date not null,
  foto_path text not null,
  order_id uuid references public.orders(id),
  notas text,
  created_by uuid references auth.users(id),
  creado_por_nombre text,
  created_at timestamptz not null default now()
);

create index if not exists facturas_area_idx on public.facturas(area_id);
create index if not exists facturas_location_idx on public.facturas(location_id);
create index if not exists facturas_fecha_idx on public.facturas(fecha_factura);

alter table public.facturas enable row level security;

-- Cualquiera con acceso al área (no solo admin) puede subir/ver/editar/borrar las facturas de esa
-- área — así quien esté en Cocina Dos Santos puede subir la foto ahí mismo, sin ser admin.
drop policy if exists facturas_select on public.facturas;
create policy facturas_select on public.facturas for select to authenticated
  using (public.es_facturas() or public.has_area_access(area_id));

drop policy if exists facturas_insert on public.facturas;
create policy facturas_insert on public.facturas for insert to authenticated
  with check (public.es_facturas() or public.has_area_access(area_id));

drop policy if exists facturas_update on public.facturas;
create policy facturas_update on public.facturas for update to authenticated
  using (public.es_facturas() or public.has_area_access(area_id))
  with check (public.es_facturas() or public.has_area_access(area_id));

drop policy if exists facturas_delete on public.facturas;
create policy facturas_delete on public.facturas for delete to authenticated
  using (public.es_facturas() or public.has_area_access(area_id));

-- 3) Quien es solo "Facturas" (sin accesos por punto/área) necesita ver el nombre de todos los
--    puntos y áreas, para el selector punto → área al crear una factura.
drop policy if exists facturas_ver_locations on public.locations;
create policy facturas_ver_locations on public.locations for select to authenticated using (public.es_facturas());

drop policy if exists facturas_ver_areas on public.areas;
create policy facturas_ver_areas on public.areas for select to authenticated using (public.es_facturas());

-- 4) Storage: bucket privado "facturas". Ruta de cada archivo: <area_id>/<AAAA-MM>/<archivo>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('facturas', 'facturas', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.facturas_puede_ver_archivo(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_area uuid;
begin
  begin v_area := split_part(p_nombre, '/', 1)::uuid; exception when others then return false; end;
  return public.es_facturas() or public.has_area_access(v_area);
end;
$$;
revoke execute on function public.facturas_puede_ver_archivo(text) from public, anon;
grant execute on function public.facturas_puede_ver_archivo(text) to authenticated, service_role;

drop policy if exists "facturas: ver" on storage.objects;
create policy "facturas: ver" on storage.objects
  for select to authenticated using (bucket_id = 'facturas' and public.facturas_puede_ver_archivo(name));
drop policy if exists "facturas: subir" on storage.objects;
create policy "facturas: subir" on storage.objects
  for insert to authenticated with check (bucket_id = 'facturas' and public.facturas_puede_ver_archivo(name));
drop policy if exists "facturas: borrar" on storage.objects;
create policy "facturas: borrar" on storage.objects
  for delete to authenticated using (bucket_id = 'facturas' and public.facturas_puede_ver_archivo(name));

-- 5) Habilita el módulo "Facturas" en todas las áreas que ya tienen Pedidos activo (igual lógica
--    que se usó para habilitar Costeo sobre Recetario en enable_costeo_modulo.sql).
update public.areas
set modules = modules || '["facturas"]'::jsonb
where modules @> '["pedidos"]'::jsonb
  and not modules @> '["facturas"]'::jsonb;

notify pgrst, 'reload schema';

-- Debe mostrar el bucket privado (public = false) con límite de 10 MB
select id, public, file_size_limit from storage.buckets where id = 'facturas';
