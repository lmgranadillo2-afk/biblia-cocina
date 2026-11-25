-- Recetas nuevas, paso 2: tipo de ficha (plato terminado o subreceta) y bloque EMPAQUE de las subrecetas
-- (referencia de empaque, rendimiento en unidades y en gramos), como la ficha de subrecetas de Dos Santos.
-- Solo agrega columnas. No borra datos. Se puede correr más de una vez. Correr ANTES de usar la app nueva.

alter table public.recetas_nuevas add column if not exists tipo text not null default 'plato';
alter table public.recetas_nuevas add column if not exists empaque_ref numeric;
alter table public.recetas_nuevas add column if not exists empaque_unidad text not null default 'g';
alter table public.recetas_nuevas add column if not exists rend_unidades numeric;
alter table public.recetas_nuevas add column if not exists rend_gramos numeric;

alter table public.recetas_nuevas drop constraint if exists recetas_nuevas_tipo_chk;
alter table public.recetas_nuevas add constraint recetas_nuevas_tipo_chk check (tipo in ('plato', 'subreceta'));

notify pgrst, 'reload schema';

-- Revisión: deben salir las 5 columnas.
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'recetas_nuevas'
  and column_name in ('tipo', 'empaque_ref', 'empaque_unidad', 'rend_unidades', 'rend_gramos');
