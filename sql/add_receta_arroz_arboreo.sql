-- Nueva receta: ARROZ ARBOREO (subreceta)
-- Área: Cocina — Puntos: Cantina Dos Santos y Dos Santos Cali
-- Código asignado: SUBC097 (siguiente disponible en ambas áreas)
-- Ingredientes: ARROZ ARBOREO INS (ABA020), FONDO DE MAR (SUBC027, subreceta), VINO BLANCO INS (ABA176)
-- Rendimiento: 16 UNIDAD (empaque de 140g c/u = 2240g totales)
-- Vida útil / almacenamiento no tienen columna propia en recipes: se guardan como observación
-- ligada al código de receta (tabla observations), igual que otras notas de recetario.

insert into recipes (code, name, yield_qty, yield_unit, ingredients, location_id, area_id)
values
(
  'SUBC097',
  'ARROZ ARBOREO',
  16,
  'UNIDAD',
  '[
    {"qty":"1000","code":"ABA020","name":"ARROZ ARBOREO INS","unit":"GR"},
    {"qty":"1000","code":"SUBC027","name":"FONDO DE MAR","unit":"GR"},
    {"qty":"500","code":"ABA176","name":"VINO BLANCO INS","unit":"GR"}
  ]'::jsonb,
  'c98db3a9-7be7-4bf6-8b77-318e6ca3098b', -- Cantina Dos Santos
  '337c3186-0313-4d88-94cb-9de043757afb'  -- Cocina
),
(
  'SUBC097',
  'ARROZ ARBOREO',
  16,
  'UNIDAD',
  '[
    {"qty":"1000","code":"ABA020","name":"ARROZ ARBOREO INS","unit":"GR"},
    {"qty":"1000","code":"SUBC027","name":"FONDO DE MAR","unit":"GR"},
    {"qty":"500","code":"ABA176","name":"VINO BLANCO INS","unit":"GR"}
  ]'::jsonb,
  '5b939dca-4d4d-455b-ad72-f21bedbfcbea', -- Dos Santos Cali
  '48a91382-4b92-4f71-9a8d-57bd255a5b8d'  -- Cocina
);

insert into observations (recipe_code, author, note, location_id, area_id)
values
(
  'SUBC097',
  'Sistema',
  'Vida útil: 20 días. Almacenamiento: Congelación. Empaque: 140 g x 16 und.',
  'c98db3a9-7be7-4bf6-8b77-318e6ca3098b',
  '337c3186-0313-4d88-94cb-9de043757afb'
),
(
  'SUBC097',
  'Sistema',
  'Vida útil: 20 días. Almacenamiento: Congelación. Empaque: 140 g x 16 und.',
  '5b939dca-4d4d-455b-ad72-f21bedbfcbea',
  '48a91382-4b92-4f71-9a8d-57bd255a5b8d'
);
