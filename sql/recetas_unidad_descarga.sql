-- Unidad de descargue en Toteat (decisión de Miguel, 25 nov 2026): la unidad en que Toteat descuenta la receta
-- o subreceta del inventario al vender (GR, KG, ML, L, UND). Es un dato de referencia para crearla igual en Toteat;
-- la app no descuenta nada con ella.
-- Se anota en la ficha de Recetas nuevas y pasa a la receta del Recetario con "Pasar al Recetario".
-- Solo agrega columnas. No borra datos. Se puede correr más de una vez. Correr ANTES de subir la app.

alter table public.recetas_nuevas add column if not exists unidad_descarga text;
alter table public.recipes add column if not exists unidad_descarga text;

alter table public.recetas_nuevas drop constraint if exists recetas_nuevas_unidad_descarga_chk;
alter table public.recetas_nuevas add constraint recetas_nuevas_unidad_descarga_chk
  check (unidad_descarga is null or unidad_descarga in ('GR', 'KG', 'ML', 'L', 'UND'));
alter table public.recipes drop constraint if exists recipes_unidad_descarga_chk;
alter table public.recipes add constraint recipes_unidad_descarga_chk
  check (unidad_descarga is null or unidad_descarga in ('GR', 'KG', 'ML', 'L', 'UND'));

notify pgrst, 'reload schema';

-- Revisión: deben salir 2 filas (recetas_nuevas y recipes).
select table_name, column_name from information_schema.columns
where table_schema = 'public' and column_name = 'unidad_descarga' and table_name in ('recetas_nuevas', 'recipes');
