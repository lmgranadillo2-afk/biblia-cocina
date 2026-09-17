-- Habilita el módulo "Costeo" en todas las áreas que ya tienen Recetario activo.
-- (El módulo Costeo depende del recetario: sin recetas no hay nada que costear.)
update areas
set modules = modules || '["costeo"]'::jsonb
where modules @> '["recetario"]'::jsonb
  and not modules @> '["costeo"]'::jsonb;
