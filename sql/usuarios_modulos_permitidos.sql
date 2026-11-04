-- Límite de pestañas por persona. null = sin límite (ve lo que tenga su área, como siempre).
-- Valores: los módulos del área (recetario, produccion, bajas...) y 'marcacion' para el botón de Marcación. El Chat no se limita.
-- Es un límite de lo que muestra la app. No borra datos; se puede correr más de una vez.
alter table public.profiles add column if not exists modulos_permitidos text[];

notify pgrst, 'reload schema';

-- Debe mostrar la columna
select column_name from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'modulos_permitidos';
